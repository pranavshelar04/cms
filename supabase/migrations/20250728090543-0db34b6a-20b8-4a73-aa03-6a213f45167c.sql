-- Create user roles enum
CREATE TYPE public.user_role AS ENUM ('admin', 'editor', 'viewer');

-- Create content status enum  
CREATE TYPE public.content_status AS ENUM ('draft', 'published', 'archived');

-- Create profiles table for additional user information
CREATE TABLE public.profiles (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  role user_role NOT NULL DEFAULT 'viewer',
  avatar_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create content table
CREATE TABLE public.content (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  body TEXT NOT NULL,
  excerpt TEXT,
  status content_status NOT NULL DEFAULT 'draft',
  featured_image_url TEXT,
  meta_title TEXT,
  meta_description TEXT,
  created_by UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
  updated_by UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
  published_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create content history table for versioning
CREATE TABLE public.content_history (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  content_id UUID NOT NULL REFERENCES public.content(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  status content_status NOT NULL,
  changed_by UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
  change_summary TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_history ENABLE ROW LEVEL SECURITY;

-- Create security definer function to check user roles
CREATE OR REPLACE FUNCTION public.get_user_role(user_id UUID)
RETURNS user_role
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT role FROM public.profiles WHERE profiles.user_id = $1;
$$;

-- RLS Policies for profiles
CREATE POLICY "Users can view all profiles" 
ON public.profiles 
FOR SELECT 
USING (true);

CREATE POLICY "Users can update their own profile" 
ON public.profiles 
FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Admins can manage all profiles" 
ON public.profiles 
FOR ALL 
USING (public.get_user_role(auth.uid()) = 'admin');

-- RLS Policies for content
CREATE POLICY "Everyone can view published content" 
ON public.content 
FOR SELECT 
USING (status = 'published' OR auth.uid() IS NOT NULL);

CREATE POLICY "Editors and admins can create content" 
ON public.content 
FOR INSERT 
WITH CHECK (
  auth.uid() IS NOT NULL AND 
  public.get_user_role(auth.uid()) IN ('editor', 'admin')
);

CREATE POLICY "Users can update their own content or admins can update all" 
ON public.content 
FOR UPDATE 
USING (
  auth.uid() = created_by OR 
  public.get_user_role(auth.uid()) = 'admin'
);

CREATE POLICY "Admins can delete all content, editors can delete their own" 
ON public.content 
FOR DELETE 
USING (
  public.get_user_role(auth.uid()) = 'admin' OR 
  (public.get_user_role(auth.uid()) = 'editor' AND auth.uid() = created_by)
);

-- RLS Policies for content history
CREATE POLICY "Authenticated users can view content history" 
ON public.content_history 
FOR SELECT 
USING (auth.uid() IS NOT NULL);

CREATE POLICY "System can insert content history" 
ON public.content_history 
FOR INSERT 
WITH CHECK (auth.uid() IS NOT NULL);

-- Function to create user profile automatically
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (user_id, full_name, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'New User'),
    CASE 
      WHEN NEW.email = 'admin@company.com' THEN 'admin'::user_role
      ELSE 'viewer'::user_role
    END
  );
  RETURN NEW;
END;
$$;

-- Trigger to create profile on user signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function to update timestamps
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for automatic timestamp updates
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_content_updated_at
  BEFORE UPDATE ON public.content
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Function to create content history on updates
CREATE OR REPLACE FUNCTION public.create_content_history()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    INSERT INTO public.content_history (
      content_id, title, body, status, changed_by, change_summary
    ) VALUES (
      OLD.id, OLD.title, OLD.body, OLD.status, NEW.updated_by, 
      'Content updated'
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for content history
CREATE TRIGGER create_content_history_trigger
  AFTER UPDATE ON public.content
  FOR EACH ROW
  EXECUTE FUNCTION public.create_content_history();

-- Insert sample data
INSERT INTO public.profiles (user_id, full_name, role) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Admin User', 'admin'),
  ('00000000-0000-0000-0000-000000000002', 'Editor User', 'editor'),
  ('00000000-0000-0000-0000-000000000003', 'Viewer User', 'viewer')
ON CONFLICT (user_id) DO NOTHING;

-- Insert sample content
INSERT INTO public.content (title, slug, body, excerpt, status, created_by, updated_by, published_at) VALUES
  (
    'Welcome to Your New CMS',
    'welcome-to-your-new-cms',
    '<p>Welcome to your new Content Management System! This platform provides everything you need to manage your website content effectively.</p><h2>Getting Started</h2><p>Use the dashboard to navigate through different sections and start creating amazing content.</p>',
    'Welcome to your new Content Management System! This platform provides everything you need to manage your website content effectively.',
    'published',
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    now()
  ),
  (
    'Draft Content Example',
    'draft-content-example',
    '<p>This is an example of draft content that is not yet published.</p>',
    'This is an example of draft content that is not yet published.',
    'draft',
    '00000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000002',
    null
  )
ON CONFLICT (slug) DO NOTHING;