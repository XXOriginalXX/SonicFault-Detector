import React, { useState, useEffect } from 'react';
import SplashScreen from './components/SplashScreen';
import HomePage from './components/HomePage';
import LoginPage from './components/LoginPage';
import AnalyzePage from './components/AnalyzePage';
import { checkBackendConnection } from './services/api';

type Page = 'splash' | 'home' | 'login' | 'analyze';

function App() {
  const [currentPage, setCurrentPage] = useState<Page>('splash');
  const [isBackendConnected, setIsBackendConnected] = useState(false);

  useEffect(() => {
    // Check backend connection
    const checkConnection = async () => {
      const connected = await checkBackendConnection();
      setIsBackendConnected(connected);
    };
    
    checkConnection();
    
    // Check connection periodically
    const interval = setInterval(checkConnection, 30000);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    // Auto transition from splash to home after 4 seconds
    if (currentPage === 'splash') {
      const timer = setTimeout(() => setCurrentPage('home'), 4000);
      return () => clearTimeout(timer);
    }
  }, [currentPage]);

  const renderPage = () => {
    switch (currentPage) {
      case 'splash':
        return <SplashScreen />;
      case 'home':
        return (
          <HomePage
            onNavigateToLogin={() => setCurrentPage('login')}
            onNavigateToAnalyze={() => setCurrentPage('analyze')}
            isBackendConnected={isBackendConnected}
          />
        );
      case 'login':
        return <LoginPage onBack={() => setCurrentPage('home')} />;
      case 'analyze':
        return (
          <AnalyzePage
            onBack={() => setCurrentPage('home')}
            isBackendConnected={isBackendConnected}
          />
        );
      default:
        return <HomePage onNavigateToLogin={() => setCurrentPage('login')} onNavigateToAnalyze={() => setCurrentPage('analyze')} isBackendConnected={isBackendConnected} />;
    }
  };

  return <div className="app">{renderPage()}</div>;
}

export default App;