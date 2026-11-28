const MESSAGE = "Hello from green (v2)";

export const handler = async () => {
  return {
    statusCode: 200,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      message: MESSAGE,
      functionVersion: process.env.AWS_LAMBDA_FUNCTION_VERSION,
      timestamp: new Date().toISOString(),
    }),
  };
};
