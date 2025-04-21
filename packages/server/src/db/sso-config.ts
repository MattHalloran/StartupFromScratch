// Stubbed database helper for fetching SSO configuration
// For smoke-test/demo we return static dummy values.
export async function getSsoConfig(): Promise<{ clientId: string; issuer: string }> {
  // Return dummy values for smoke-testing
  return {
    clientId: 'dummy-client-id',
    issuer:  'http://dummy-issuer',
  };
} 