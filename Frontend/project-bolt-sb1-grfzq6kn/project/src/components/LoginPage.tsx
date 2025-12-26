import React, { useState } from 'react';
import { Engine, User, Lock, ArrowLeft } from './icons/CustomIcons';

interface LoginPageProps {
  onBack: () => void;
}

const LoginPage: React.FC<LoginPageProps> = ({ onBack }) => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');

  return (
    <div className="login-page">
      {/* Animated car dashboard background */}
      <div className="dashboard-background">
        <div className="dashboard-glow"></div>
        <div className="speedometer">
          <div className="speedometer-needle"></div>
        </div>
        <div className="dashboard-lights">
          {[...Array(8)].map((_, i) => (
            <div key={i} className={`dash-light light-${i + 1}`}></div>
          ))}
        </div>
      </div>

      <div className="login-container">
        <button className="back-button" onClick={onBack}>
          <ArrowLeft />
        </button>

        <div className="login-form-wrapper">
          <div className="login-header">
            <div className="login-logo">
              <Engine />
            </div>
            <h1>Access Portal</h1>
            <p>Secure access to vehicle diagnostics system</p>
          </div>

          <form className="login-form">
            <div className="input-group">
              <div className="input-icon">
                <User />
              </div>
              <input
                type="text"
                placeholder="Engineer ID / Username"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                className="login-input"
              />
            </div>

            <div className="input-group">
              <div className="input-icon">
                <Lock />
              </div>
              <input
                type="password"
                placeholder="Access Code"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="login-input"
              />
            </div>

            <button type="submit" className="login-submit">
              <span>AUTHENTICATE</span>
              <div className="submit-glow"></div>
            </button>
          </form>

          <div className="login-footer">
            <div className="security-badge">
              <Lock />
              <span>Secured by Advanced Encryption</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default LoginPage;