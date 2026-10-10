# Environment Configuration

This application uses environment variables for configuration management through `.env` files.

## Setup Instructions

1. **Copy the example file:**

   ```bash
   cp .env.example .env
   ```

2. **Update the `.env` file with your actual credentials:**
   - Replace `your_firebase_api_key_here` with your actual Firebase API key
   - Update `ADMIN_EMAIL` and `ADMIN_PASSWORD` with your admin credentials
   - Set your Firebase project configuration
   - Generate secure secrets for JWT and encryption

## Environment Variables

### Required Variables

- `FIREBASE_API_KEY` - Your Firebase API key
- `FIREBASE_DATABASE_URL` - Your Firebase Realtime Database URL
- `ADMIN_EMAIL` - Admin user email
- `ADMIN_PASSWORD` - Admin user password (must be secure)

### Optional Variables

- `ENVIRONMENT` - Environment type (development, staging, production)
- `API_BASE_URL` - Base URL for API calls
- `API_TIMEOUT_SECONDS` - API request timeout
- `DEFAULT_DEVICE_PORT` - Default port for ESP32 devices
- `DEFAULT_AP_PASSWORD` - Default password for ESP32 AP mode
- `JWT_SECRET` - Secret for JWT token signing
- `ENCRYPTION_KEY` - Key for data encryption
- `ENABLE_LOGGING` - Enable/disable logging
- `LOG_LEVEL` - Logging level (debug, info, warning, error)

## Security Notes

⚠️ **IMPORTANT SECURITY GUIDELINES:**

1. **Never commit actual credentials to version control**
2. **Use strong, unique passwords**
3. **Generate cryptographically secure secrets**
4. **Use different credentials for each environment**
5. **Regularly rotate secrets and passwords**

## Environment-Specific Configuration

### Development

```bash
ENVIRONMENT=development
ENABLE_LOGGING=true
LOG_LEVEL=debug
```

### Staging

```bash
ENVIRONMENT=staging
ENABLE_LOGGING=true
LOG_LEVEL=info
```

### Production

```bash
ENVIRONMENT=production
ENABLE_LOGGING=false
LOG_LEVEL=error
```

## Validation

The application will validate that all required environment variables are set on startup. If any are missing, you'll see warnings in the debug console.

## Troubleshooting

If you see warnings about missing environment variables:

1. Check that your `.env` file exists in the app directory
2. Verify all required variables are set
3. Ensure the `.env` file is included in `pubspec.yaml` assets
4. Restart the application after making changes
