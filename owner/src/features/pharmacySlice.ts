import { createSlice } from '@reduxjs/toolkit';
import { api, qs } from '../api/client';
import { makeThunk } from '../api/thunk';
import type { Dispense, Medicine, PatientPrescription } from '../types';

export interface MedicineFilter { search?: string; category?: string; lowStock?: boolean; expiring?: boolean; includeInactive?: boolean }
export type MedicineInput = Partial<Omit<Medicine, 'id' | 'isLowStock' | 'isExpired'>>;

export const fetchMedicines = makeThunk('pharmacy/medicines', (f: MedicineFilter = {}) =>
  api<Medicine[]>('/api/pharmacy/medicines' + qs({ ...f })));
export const saveMedicine = makeThunk('pharmacy/save', (a: { id?: number; data: MedicineInput }) =>
  a.id ? api(`/api/pharmacy/medicines/${a.id}`, { method: 'PUT', body: a.data }) : api('/api/pharmacy/medicines', { method: 'POST', body: a.data }));
export const restockMedicine = makeThunk('pharmacy/restock', (a: { id: number; quantity: number; batchNumber?: string; expiryDate?: string }) =>
  api(`/api/pharmacy/medicines/${a.id}/restock`, { method: 'POST', body: { quantity: a.quantity, batchNumber: a.batchNumber, expiryDate: a.expiryDate } }));
export const deleteMedicine = makeThunk('pharmacy/delete', (id: number) => api(`/api/pharmacy/medicines/${id}`, { method: 'DELETE' }));

export const dispenseMedicine = makeThunk('pharmacy/dispense', (d: { patientId: number; medicineId: number; quantity: number; prescriptionId?: number; notes?: string }) =>
  api('/api/pharmacy/dispense', { method: 'POST', body: d }));
export const fetchDispenses = makeThunk('pharmacy/dispenses', () => api<Dispense[]>('/api/pharmacy/dispenses'));
export const fetchPrescriptions = makeThunk('pharmacy/prescriptions', (patientId: number) =>
  api<PatientPrescription[]>(`/api/pharmacy/prescriptions/patient/${patientId}`));

const slice = createSlice({
  name: 'pharmacy',
  initialState: { medicines: [] as Medicine[], dispenses: [] as Dispense[], prescriptions: [] as PatientPrescription[], loading: false },
  reducers: { clearPrescriptions(s) { s.prescriptions = []; } },
  extraReducers: (b) => {
    b.addCase(fetchMedicines.fulfilled, (s, a) => { s.medicines = a.payload; })
      .addCase(fetchDispenses.fulfilled, (s, a) => { s.dispenses = a.payload; })
      .addCase(fetchPrescriptions.fulfilled, (s, a) => { s.prescriptions = a.payload; })
      .addMatcher((a) => a.type.startsWith('pharmacy/') && a.type.endsWith('/pending'), (s) => { s.loading = true; })
      .addMatcher((a) => a.type.startsWith('pharmacy/') && (a.type.endsWith('/fulfilled') || a.type.endsWith('/rejected')), (s) => { s.loading = false; });
  },
});
export const { clearPrescriptions } = slice.actions;
export default slice.reducer;
