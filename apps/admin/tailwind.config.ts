import type { Config } from 'tailwindcss';

export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        cyanZone: {
          cyan: '#00A7B7',
          ink: '#172026',
          gold: '#FFC857',
          mist: '#F4FAFA',
        },
      },
    },
  },
  plugins: [],
} satisfies Config;
