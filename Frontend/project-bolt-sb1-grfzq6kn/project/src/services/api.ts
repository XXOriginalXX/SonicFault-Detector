const API_BASE_URL = 'http://127.0.0.1:8000';

export interface AnalyzeResult {
  status: 'success' | 'error';
  result?: {
    detected_issue: string;
    detected_issue_key: string;
    confidence: number;
  };
  message?: string;
}

export interface DIYSolution {
  issue: string;
  severity: string;
  diy_possible: boolean;
  steps: string[];
  tools_needed: string[];
  estimated_time: string;
  warning: string;
}

export interface RoadsideAssistance {
  country: string;
  national_helplines: Array<{name: string; number: string}>;
  brand_assistance?: {number: string; availability: string};
}

export interface ServiceCenter {
  name: string;
  address: string;
  phone?: string;
  rating?: number;
  distance?: string;
  place_id?: string;
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

export const uploadAudio = async (file: File): Promise<AnalyzeResult> => {
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

    return await response.json();
  } catch (error) {
    console.error('Upload failed:', error);
    return {
      status: 'error',
      message: 'Failed to upload and analyze audio file'
    };
  }
};

export const connectWebSocket = (onMessage: (data: AnalyzeResult) => void): WebSocket | null => {
  try {
    // Changed from Render URL to Localhost
    const ws = new WebSocket('ws://127.0.0.1:8000/live-audio');
    
    ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        onMessage(data);
      } catch (e) {
        console.error("Error parsing WS message:", e);
      }
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

export const getDIYSolution = async (issueKey: string): Promise<{status: string; solution?: DIYSolution; message?: string}> => {
  try {
    const response = await fetch(`${API_BASE_URL}/diy-solution/${issueKey}`);
    return await response.json();
  } catch (error) {
    console.error('Failed to fetch DIY solution:', error);
    return {status: 'error', message: 'Failed to fetch solution'};
  }
};

export const getRoadsideAssistance = async (country: string = 'India', brand?: string): Promise<RoadsideAssistance | null> => {
  try {
    const url = brand 
      ? `${API_BASE_URL}/roadside-assistance?country=${country}&brand=${encodeURIComponent(brand)}`
      : `${API_BASE_URL}/roadside-assistance?country=${country}`;
    
    const response = await fetch(url);
    const data = await response.json();
    return data.status === 'success' ? data : null;
  } catch (error) {
    console.error('Failed to fetch roadside assistance:', error);
    return null;
  }
};

export const searchNearbyServiceCenters = async (
  latitude: number,
  longitude: number,
  brand?: string
): Promise<ServiceCenter[]> => {
  // Placeholder for Google Places logic
  return [];
};