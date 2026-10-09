import { createSlice } from '@reduxjs/toolkit';
import { api, qs } from '../api/client';
import { makeThunk } from '../api/thunk';
import type { Doctor, Patient, StaffUser, Stats } from '../types';

export interface NewUser {
  fullName: string; email: string; password: string; role: string; phone?: string;
  specialization?: string; licenseNumber?: string; consultationFee?: number; yearsOfExperience?: number;
  dateOfBirth?: string; gender?: string; bloodGroup?: string; address?: string; emergencyContact?: string;
}

export const fetchStats = makeThunk('users/stats', () => api<Stats>('/api/admin/stats'));
export const fetchPatients = makeThunk('users/patients', () => api<Patient[]>('/api/patients'));
export const fetchDoctors = makeThunk('users/doctors', (specialization?: string) => api<Doctor[]>('/api/doctors' + qs({ specialization })));
export const fetchUsers = makeThunk('users/all', () => api<StaffUser[]>('/api/admin/users'));
export const createUser = makeThunk('users/create', (u: NewUser) => api('/api/admin/users', { method: 'POST', body: u }));
export const updatePatient = makeThunk('users/updatePatient', (a: { id: number; data: Record<string, unknown> }) =>
  api(`/api/admin/patients/${a.id}`, { method: 'PUT', body: a.data }));
export const updateDoctor = makeThunk('users/updateDoctor', (a: { id: number; data: Record<string, unknown> }) =>
  api(`/api/admin/doctors/${a.id}`, { method: 'PUT', body: a.data }));
export const updateUser = makeThunk('users/update', (a: { id: number; data: Record<string, unknown> }) =>
  api(`/api/admin/users/${a.id}`, { method: 'PUT', body: a.data }));
export const deleteUser = makeThunk('users/delete', (userId: number) => api(`/api/admin/users/${userId}`, { method: 'DELETE' }));

const slice = createSlice({
  name: 'users',
  initialState: { stats: null as Stats | null, patients: [] as Patient[], doctors: [] as Doctor[], users: [] as StaffUser[], loading: false },
  reducers: {},
  extraReducers: (b) => {
    b.addCase(fetchStats.fulfilled, (s, a) => { s.stats = a.payload; })
      .addCase(fetchPatients.fulfilled, (s, a) => { s.patients = a.payload; })
      .addCase(fetchDoctors.fulfilled, (s, a) => { s.doctors = a.payload; })
      .addCase(fetchUsers.fulfilled, (s, a) => { s.users = a.payload; })
      .addMatcher((a) => a.type.startsWith('users/') && a.type.endsWith('/pending'), (s) => { s.loading = true; })
      .addMatcher((a) => a.type.startsWith('users/') && (a.type.endsWith('/fulfilled') || a.type.endsWith('/rejected')), (s) => { s.loading = false; });
  },
});
export default slice.reducer;
