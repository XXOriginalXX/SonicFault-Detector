import React from 'react';
import { Engine, Gear, Signal } from './icons/CustomIcons';

const SplashScreen: React.FC = () => {
  return (
    <div className="splash-screen">
      <div className="splash-content">
        {/* Animated background elements */}
        <div className="engine-backdrop">
          <div className="gear-container gear-1">
            <Gear />
          </div>
          <div className="gear-container gear-2">
            <Gear />
          </div>
          <div className="gear-container gear-3">
            <Gear />
          </div>
        </div>

        {/* Main content */}
        <div className="splash-main">
          <div className="engine-icon">
            <Engine />
          </div>
          
          <h1 className="brand-title">
            <span className="sonic">SONIC</span>
            <span className="fault">FAULT</span>
          </h1>
          
          <div className="subtitle">
            <Signal />
            <span>DETECTOR</span>
          </div>
          
          <div className="loading-bar">
            <div className="loading-fill"></div>
          </div>
          
          <p className="loading-text">Initializing Engine Diagnostics...</p>
        </div>

        {/* Particle effects */}
        <div className="particles">
          {[...Array(20)].map((_, i) => (
            <div key={i} className={`particle particle-${i + 1}`}></div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default SplashScreen;