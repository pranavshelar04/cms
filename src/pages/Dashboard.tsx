import React from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { useNavigate } from 'react-router-dom';
import { 
  FileText, 
  Users, 
  Settings, 
  Plus,
  BarChart3,
  LogOut,
  Layout
} from 'lucide-react';

const Dashboard = () => {
  const { user, userRole, signOut } = useAuth();
  const navigate = useNavigate();

  const stats = [
    { title: 'Total Content', value: '24', icon: FileText },
    { title: 'Published', value: '18', icon: Layout },
    { title: 'Drafts', value: '6', icon: FileText },
    { title: 'Users', value: '12', icon: Users },
  ];

  const quickActions = [
    {
      title: 'Create Content',
      description: 'Write a new article or page',
      icon: Plus,
      action: () => navigate('/content/new'),
      roles: ['admin', 'editor']
    },
    {
      title: 'Manage Content',
      description: 'View and edit existing content',
      icon: FileText,
      action: () => navigate('/content'),
      roles: ['admin', 'editor', 'viewer']
    },
    {
      title: 'Manage Users',
      description: 'Add and manage user accounts',
      icon: Users,
      action: () => navigate('/users'),
      roles: ['admin']
    },
    {
      title: 'Settings',
      description: 'Configure system settings',
      icon: Settings,
      action: () => navigate('/settings'),
      roles: ['admin']
    },
  ];

  const filteredActions = quickActions.filter(action => 
    action.roles.includes(userRole || 'viewer')
  );

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b bg-card">
        <div className="container mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold">Dashboard</h1>
              <p className="text-muted-foreground">
                Welcome back, {user?.email} ({userRole})
              </p>
            </div>
            <Button variant="outline" onClick={signOut}>
              <LogOut className="mr-2 h-4 w-4" />
              Sign Out
            </Button>
          </div>
        </div>
      </header>

      <div className="container mx-auto px-6 py-8">
        {/* Stats Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          {stats.map((stat, index) => (
            <Card key={index}>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">
                  {stat.title}
                </CardTitle>
                <stat.icon className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{stat.value}</div>
              </CardContent>
            </Card>
          ))}
        </div>

        {/* Quick Actions */}
        <div className="mb-8">
          <h2 className="text-xl font-semibold mb-4">Quick Actions</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {filteredActions.map((action, index) => (
              <Card key={index} className="cursor-pointer hover:shadow-md transition-shadow">
                <CardHeader>
                  <CardTitle className="flex items-center">
                    <action.icon className="mr-2 h-5 w-5" />
                    {action.title}
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-muted-foreground mb-4">{action.description}</p>
                  <Button onClick={action.action} className="w-full">
                    Get Started
                  </Button>
                </CardContent>
              </Card>
            ))}
          </div>
        </div>

        {/* Recent Activity */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center">
              <BarChart3 className="mr-2 h-5 w-5" />
              Recent Activity
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div className="flex items-center justify-between p-4 border rounded-lg">
                <div>
                  <p className="font-medium">Welcome article published</p>
                  <p className="text-sm text-muted-foreground">2 hours ago</p>
                </div>
                <div className="text-sm text-muted-foreground">Admin User</div>
              </div>
              <div className="flex items-center justify-between p-4 border rounded-lg">
                <div>
                  <p className="font-medium">New user registered</p>
                  <p className="text-sm text-muted-foreground">1 day ago</p>
                </div>
                <div className="text-sm text-muted-foreground">System</div>
              </div>
              <div className="flex items-center justify-between p-4 border rounded-lg">
                <div>
                  <p className="font-medium">Content updated</p>
                  <p className="text-sm text-muted-foreground">3 days ago</p>
                </div>
                <div className="text-sm text-muted-foreground">Editor User</div>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default Dashboard;