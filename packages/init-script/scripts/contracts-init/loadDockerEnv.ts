import dotenv from 'dotenv';

const { NODE_ENV } = process.env;

dotenv.config({
  path: `.env${NODE_ENV ? `.${NODE_ENV}` : ''}`,
});
