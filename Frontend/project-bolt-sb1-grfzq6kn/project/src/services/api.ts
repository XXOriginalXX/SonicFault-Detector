const API_BASE_URL = 'http://localhost:8000';

export interface analyzeResult {
  status: 'success' | 'error';
  result?: {
    detected_issue: string;
    confidence_scores: Record<string, number>;
  };
  message?: string;
}

export const checkBackendConnection = async (): Promise<boolean> => {
  try {
    const response = await fetch(`${API_BASE_URL}/`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
      },
    });
    return response.ok;
  } catch (error) {
    console.error('Backend connection failed:', error);
    return false;
  }
};

export const uploadAudio = async (file: File): Promise<analyzeResult> => {
  try {
    const formData = new FormData();
    formData.append('file', file);

    const response = await fetch(`${API_BASE_URL}/upload-audio`, {
      method: 'POST',
      body: formData,
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const result = await response.json();
    return result;
  } catch (error) {
    console.error('Upload failed:', error);
    return {
      status: 'error',
      message: 'Failed to upload and analyze audio file'
    };
  }
};

export const connectWebSocket = (onMessage: (data: analyzeResult) => void): WebSocket | null => {
  try {
    const ws = new WebSocket('ws://localhost:8000/live-audio');
    
    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      onMessage(data);
    };

    ws.onerror = (error) => {
      console.error('WebSocket error:', error);
    };

    return ws;
  } catch (error) {
    console.error('Failed to connect WebSocket:', error);
    return null;
  }
};