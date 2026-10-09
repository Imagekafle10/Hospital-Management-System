import { createSlice } from '@reduxjs/toolkit';
import { api, qs } from '../api/client';
import { makeThunk } from '../api/thunk';
import type { Admission, Appointment, Bed, Payment, Ward } from '../types';

// ---- Appointments
export const fetchAppointments = makeThunk('hospital/appointments', () => api<Appointment[]>('/api/appointments'));
export const setAppointmentStatus = makeThunk('hospital/apptStatus', (a: { id: number; status: string; notes?: string }) =>
  api(`/api/appointments/${a.id}/status`, { method: 'PUT', body: { status: a.status, notes: a.notes } }));

// ---- Wards & beds
export const fetchWards = makeThunk('hospital/wards', () => api<Ward[]>('/api/wards'));
export const saveWard = makeThunk('hospital/saveWard', (a: { id?: number; data: Partial<Ward> }) =>
  a.id ? api(`/api/wards/${a.id}`, { method: 'PUT', body: a.data }) : api('/api/wards', { method: 'POST', body: a.data }));
export const deleteWard = makeThunk('hospital/deleteWard', (id: number) => api(`/api/wards/${id}`, { method: 'DELETE' }));
export const fetchBeds = makeThunk('hospital/beds', (status?: string) => api<Bed[]>('/api/beds' + qs({ status })));
export const addBed = makeThunk('hospital/addBed', (a: { wardId: number; bedNumber: string }) =>
  api(`/api/wards/${a.wardId}/beds`, { method: 'POST', body: { bedNumber: a.bedNumber } }));
export const setBedStatus = makeThunk('hospital/bedStatus', (a: { id: number; status: string }) =>
  api(`/api/beds/${a.id}/status`, { method: 'PUT', body: { status: a.status } }));
export const deleteBed = makeThunk('hospital/deleteBed', (id: number) => api(`/api/beds/${id}`, { method: 'DELETE' }));

// ---- Admissions
export const fetchAdmissions = makeThunk('hospital/admissions', () => api<Admission[]>('/api/admissions/active'));
export const admitPatient = makeThunk('hospital/admit', (d: { patientId: number; bedId: number; reasonForAdmission: string; admittingDoctorId: number; expectedDischargeDate?: string }) =>
  api('/api/admissions', { method: 'POST', body: d }));
export const dischargePatient = makeThunk('hospital/discharge', (a: { id: number; dischargeSummary?: string }) =>
  api(`/api/admissions/${a.id}/discharge`, { method: 'PUT', body: { dischargeSummary: a.dischargeSummary } }));

// ---- Payments
export const fetchPayments = makeThunk('hospital/payments', () => api<Payment[]>('/api/payments'));
export const collectCod = makeThunk('hospital/collect', (id: number) => api(`/api/payments/${id}/collect`, { method: 'PUT' }));

const slice = createSlice({
  name: 'hospital',
  initialState: {
    appointments: [] as Appointment[], wards: [] as Ward[], beds: [] as Bed[],
    admissions: [] as Admission[], payments: [] as Payment[], loading: false,
  },
  reducers: {},
  extraReducers: (b) => {
    b.addCase(fetchAppointments.fulfilled, (s, a) => { s.appointments = a.payload; })
      .addCase(fetchWards.fulfilled, (s, a) => { s.wards = a.payload; })
      .addCase(fetchBeds.fulfilled, (s, a) => { s.beds = a.payload; })
      .addCase(fetchAdmissions.fulfilled, (s, a) => { s.admissions = a.payload; })
      .addCase(fetchPayments.fulfilled, (s, a) => { s.payments = a.payload; })
      .addMatcher((a) => a.type.startsWith('hospital/') && a.type.endsWith('/pending'), (s) => { s.loading = true; })
      .addMatcher((a) => a.type.startsWith('hospital/') && (a.type.endsWith('/fulfilled') || a.type.endsWith('/rejected')), (s) => { s.loading = false; });
  },
});
export default slice.reducer;
