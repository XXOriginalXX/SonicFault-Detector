import React from 'react';

export const Engine: React.FC = () => (
  <svg viewBox="0 0 48 48" fill="currentColor">
    <path d="M8 16h32v16H8z" />
    <rect x="12" y="8" width="6" height="8" />
    <rect x="30" y="8" width="6" height="8" />
    <rect x="12" y="32" width="6" height="8" />
    <rect x="30" y="32" width="6" height="8" />
    <circle cx="16" cy="24" r="3" />
    <circle cx="32" cy="24" r="3" />
    <rect x="20" y="20" width="8" height="8" rx="2" />
  </svg>
);

export const Gear: React.FC = () => (
  <svg viewBox="0 0 48 48" fill="currentColor">
    <path d="M24 4l3 6h6l-1.5 5.5L37 19l-5.5 1.5L33 26h-6l-3 6-3-6h-6l1.5-5.5L11 19l5.5-1.5L15 12h6l3-8z" />
    <circle cx="24" cy="24" r="6" fill="none" stroke="currentColor" strokeWidth="2" />
  </svg>
);

export const Signal: React.FC = () => (
  <svg viewBox="0 0 48 48" fill="currentColor">
    <rect x="4" y="36" width="6" height="8" />
    <rect x="12" y="28" width="6" height="16" />
    <rect x="20" y="20" width="6" height="24" />
    <rect x="28" y="12" width="6" height="32" />
    <rect x="36" y="4" width="6" height="40" />
  </svg>
);

export const Network: React.FC = () => (
  <svg viewBox="0 0 48 48" fill="currentColor">
    <circle cx="12" cy="12" r="4" />
    <circle cx="36" cy="12" r="4" />
    <circle cx="12" cy="36" r="4" />
    <circle cx="36" cy="36" r="4" />
    <circle cx="24" cy="24" r="4" />
    <path d="M16 12h16M16 36h16M12 16v16M36 16v16M16 16l12 12M32 16L20 28" stroke="currentColor" strokeWidth="2" />
  </svg>
);

export const User: React.FC = () => (
  <svg viewBox="0 0 48 48" fill="currentColor">
    <circle cx="24" cy="16" r="8" />
    <path d="M24 28c-8 0-16 4-16 12h32c0-8-8-12-16-12z" />
  </svg>
);

export const Analysis: React.FC = () => (
  <svg viewBox="0 0 48 48" fill="currentColor">
    <path d="M8 40V8h4v32zM16 40V20h4v20zM24 40V12h4v28zM32 40V24h4v16zM40 40V16h4v24z" />
    <circle cx="10" cy="8" r="2" />
    <circle cx="18" cy="20" r="2" />
    <circle cx="26" cy="12" r="2" />
    <circle cx="34" cy="24" r="2" />
    <circle cx="42" cy="16" r="2" />
  </svg>
);

export const Mic: React.FC = () => (
  <svg viewBox="0 0 48 48" fill="currentColor">
    <rect x="20" y="8" width="8" height="16" rx="4" />
    <path d="M16 20c0 4.4 3.6 8 8 8s8-3.6 8-8M24 28v8M20 36h8" stroke="currentColor" strokeWidth="2" fill="none" />
  </svg>
);

export const Upload: React.FC = () => (
  <svg viewBox="0 0 48 48" fill="currentColor">
    <path d="M24 8l8 8h-5v12h-6V16h-5l8-8z" />
    <rect x="8" y="32" width="32" height="8" rx="2" />
  </svg>
);

export const Play: React.FC = () => (
  <svg viewBox="0 0 48 48" fill="currentColor">
    <path d="M16 12l20 12-20 12V12z" />
  </svg>
);

export const Pause: React.FC = () => (
  <svg viewBox="0 0 48 48" fill="currentColor">
    <rect x="16" y="12" width="6" height="24" />
    <rect x="26" y="12" width="6" height="24" />
  </svg>
);

export const Lock: React.FC = () => (
  <svg viewBox="0 0 48 48" fill="currentColor">
    <rect x="12" y="20" width="24" height="20" rx="2" />
    <path d="M16 20v-4c0-4.4 3.6-8 8-8s8 3.6 8 8v4" stroke="currentColor" strokeWidth="2" fill="none" />
  </svg>
);

export const ArrowLeft: React.FC = () => (
  <svg viewBox="0 0 48 48" fill="currentColor">
    <path d="M32 12l-12 12 12 12v-8h12v-8H32v-8z" />
  </svg>
);

export const AlertCircle: React.FC = () => (
  <svg viewBox="0 0 48 48" fill="currentColor">
    <circle cx="24" cy="24" r="20" stroke="currentColor" strokeWidth="2" fill="none" />
    <path d="M24 16v8M24 32h.01" stroke="currentColor" strokeWidth="2" />
  </svg>
);