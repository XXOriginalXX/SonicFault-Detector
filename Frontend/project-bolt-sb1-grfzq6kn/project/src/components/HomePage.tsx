import React from 'react';
import { Engine, Signal, Network, User, Analysis } from './icons/CustomIcons';

interface HomePageProps {
  onNavigateToLogin: () => void;
  onNavigateToAnalyze: () => void;
  isBackendConnected: boolean;
}

const HomePage: React.FC<HomePageProps> = ({ onNavigateToLogin, onNavigateToAnalyze, isBackendConnected }) => {
  return (
    <div className="home-page">
      {/* Animated background */}
      <div className="home-background">
        <div className="engine-grid">
          {[...Array(12)].map((_, i) => (
            <div key={i} className={`grid-item grid-${i + 1}`}>
              <Engine />
            </div>
          ))}
        </div>
        <div className="circuit-overlay"></div>
      </div>

      {/* Header */}
      <header className="home-header">
        <div className="logo-section">
          <Engine />
          <span className="logo-text">SonicFault</span>
        </div>
        
        <div className="connection-status">
          <div className={`status-indicator ${isBackendConnected ? 'connected' : 'disconnected'}`}>
            <Network />
            <span>{isBackendConnected ? 'CONNECTED' : 'DISCONNECTED'}</span>
          </div>
        </div>
      </header>

      {/* Main content */}
      <main className="home-main">
        <div className="hero-section">
          <h1 className="hero-title">
            Advanced Vehicle Acoustic
            <span className="highlight">Fault Detection</span>
          </h1>
          
          <p className="hero-description">
            Real-time engine diagnostics through advanced audio analysis and machine learning algorithms.
            Detect vehicle issues before they become critical problems.
          </p>

          <div className="action-buttons">
            <button className="btn btn-primary" onClick={onNavigateToAnalyze}>
              <Analysis />
              <span>START ANALYSIS</span>
              <div className="btn-glow"></div>
            </button>
            
            <button className="btn btn-secondary" onClick={onNavigateToLogin}>
              <User />
              <span>ACCESS PORTAL</span>
            </button>
          </div>
        </div>

        <div className="info-section">
          <div className="info-grid">
            <div className="info-card">
              <h3>Project Background</h3>
              <p>
                Developed by automobile engineering students at <strong>Sree Chitra Thirunal College of Engineering</strong>, 
                this cutting-edge system combines acoustic analysis with machine learning to revolutionize vehicle diagnostics.
              </p>
            </div>
            
            <div className="info-card">
              <h3>Advanced Technology</h3>
              <p>
                Utilizing MFCC (Mel-Frequency Cepstral Coefficients) feature extraction and deep learning models 
                to identify engine anomalies through sound pattern analysis with 95%+ accuracy.
              </p>
            </div>
            
            <div className="info-card">
              <h3>Real-time Detection</h3>
              <p>
                Support for both live audio streaming and uploaded audio files. 
                Get instant feedback on potential vehicle issues with confidence scores and detailed analysis.
              </p>
            </div>
          </div>
        </div>

        {/* College info */}
        <div className="college-section">
          <div className="college-info">
            <h2>Sree Chitra Thirunal College of Engineering</h2>
            <p>
              A premier engineering institution in Thiruvananthapuram, Kerala, known for excellence in 
              technical education and innovative research. Our automobile engineering department continues 
              to push boundaries in automotive technology and sustainable transportation solutions.
            </p>
          </div>
        </div>
      </main>
    </div>
  );
};

export default HomePage;