import * as Minio from 'minio';
import * as dotenv from 'dotenv';

dotenv.config();

const rawEndpoint = process.env.MINIO_ENDPOINT || 'localhost';
const cleanEndpoint = rawEndpoint.replace(/^https?:\/\//i, '').replace(/\/.*$/, '');

export const minioClient = new Minio.Client({
  endPoint: cleanEndpoint,
  port: Number(process.env.MINIO_PORT) || 9000,
  useSSL: process.env.MINIO_USE_SSL === 'true' || process.env.MINIO_SSL === 'true',
  accessKey: process.env.MINIO_ACCESS_KEY || 'your_minio_access_key',
  secretKey:
    process.env.MINIO_SECRET_KEY || 'your_minio_secret_key',
});
