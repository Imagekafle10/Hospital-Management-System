import { createSlice } from '@reduxjs/toolkit';
import { api } from '../api/client';
import { makeThunk } from '../api/thunk';
import type { AuthUser } from '../types';

const KEY = 'hms_auth';

function load(): AuthUser | null {
  try {
    const u = JSON.parse(localStorage.getItem(KEY) ?? 'null') as AuthUser | null;
    if (u && new Date(u.expiresAt) > new Date() && (u.role === 'Admin' || u.role === 'Pharmacist')) return u;
  } catch { /* ignore */ }
  localStorage.removeItem(KEY); localStorage.removeItem('hms_token');
  return null;
}

export const login = makeThunk('auth/login', async (b: { email: string; password: string }) => {
  const u = await api<AuthUser>('/api/auth/login', { method: 'POST', body: b });
  if (u.role !== 'Admin' && u.role !== 'Pharmacist') throw new Error('This panel is only for Admin and Pharmacist accounts.');
  localStorage.setItem('hms_token', u.token);
  localStorage.setItem(KEY, JSON.stringify(u));
  return u;
});

const slice = createSlice({
  name: 'auth',
  initialState: { user: load(), loading: false, error: null as string | null },
  reducers: {
    logout(s) {
      s.user = null; localStorage.removeItem(KEY); localStorage.removeItem('hms_token');
    },
  },
  extraReducers: (b) => {
    b.addCase(login.pending, (s) => { s.loading = true; s.error = null; })
      .addCase(login.fulfilled, (s, a) => { s.loading = false; s.user = a.payload; })
      .addCase(login.rejected, (s, a) => { s.loading = false; s.error = a.payload ?? 'Login failed'; });
  },
});

export const { logout } = slice.actions;
export default slice.reducer;
