import { useEffect, useState, type FormEvent } from 'react';
import { useAppDispatch, useAppSelector } from '../app/hooks';
import { createUser, deleteUser, fetchPatients, fetchUsers, updatePatient, updateUser } from '../features/usersSlice';
import { Badge, Field, FormActions, FormError, Modal, Page, Select, Table, d10, opt, useForm, useSubmit } from '../components/ui';
import type { Patient } from '../types';

const GENDERS = ['Male', 'Female', 'Other'].map((g) => ({ value: g, label: g }));
const BLOOD = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map((g) => ({ value: g, label: g }));

function PatientForm({ patient, onClose, onSaved }: { patient?: Patient; onClose: () => void; onSaved: () => void }) {
  const dispatch = useAppDispatch();
  const { busy, err, run } = useSubmit();
  const f = useForm({
    fullName: patient?.fullName ?? '', email: patient?.email ?? '', phone: patient?.phone ?? '', password: '',
    dateOfBirth: d10(patient?.dateOfBirth), gender: patient?.gender ?? '', bloodGroup: patient?.bloodGroup ?? '',
    address: patient?.address ?? '', emergencyContact: patient?.emergencyContact ?? '',
  });

  const submit = (e: FormEvent) => {
    e.preventDefault();
    const v = f.v;
    const profile = { dateOfBirth: opt(v.dateOfBirth), gender: opt(v.gender), bloodGroup: opt(v.bloodGroup), address: opt(v.address), emergencyContact: opt(v.emergencyContact) };
    run(async () => {
      if (patient) {
        await dispatch(updatePatient({ id: patient.id, data: { fullName: v.fullName, email: v.email, phone: opt(v.phone), newPassword: opt(v.password), ...profile } })).unwrap();
      } else {
        await dispatch(createUser({ role: 'Patient', fullName: v.fullName, email: v.email, password: v.password, phone: opt(v.phone), ...profile })).unwrap();
      }
    }, () => { onSaved(); onClose(); });
  };

  return (
    <Modal title={patient ? 'Edit patient' : 'Add patient'} onClose={onClose}>
      <form onSubmit={submit}>
        <div className="grid2">
          <Field label="Full name" required {...f.bind('fullName')} />
          <Field label="Email" type="email" required {...f.bind('email')} />
          <Field label="Phone" {...f.bind('phone')} />
          <Field label={patient ? 'New password (optional)' : 'Password'} type="password" required={!patient} {...f.bind('password')} />
          <Field label="Date of birth" type="date" {...f.bind('dateOfBirth')} />
          <Select label="Gender" options={GENDERS} {...f.bind('gender')} />
          <Select label="Blood group" options={BLOOD} {...f.bind('bloodGroup')} />
          <Field label="Emergency contact" {...f.bind('emergencyContact')} />
        </div>
        <Field label="Address" {...f.bind('address')} />
        <FormError msg={err} />
        <FormActions busy={busy} onCancel={onClose} />
      </form>
    </Modal>
  );
}

export default function Patients() {
  const dispatch = useAppDispatch();
  const { patients, users, loading } = useAppSelector((s) => s.users);
  const [q, setQ] = useState('');
  const [editing, setEditing] = useState<Patient | 'new' | null>(null);
  const [msg, setMsg] = useState('');

  const load = () => { dispatch(fetchPatients()); dispatch(fetchUsers()); };
  useEffect(load, [dispatch]);

  const activeOf = (userId: number) => users.find((u) => u.id === userId)?.isActive ?? true;
  const rows = patients.filter((p) => `${p.fullName} ${p.email} ${p.phone}`.toLowerCase().includes(q.toLowerCase()));

  const toggle = async (p: Patient) => {
    try { await dispatch(updateUser({ id: p.userId, data: { isActive: !activeOf(p.userId) } })).unwrap(); load(); } catch (e) { setMsg(String(e)); }
  };
  const remove = async (p: Patient) => {
    if (!confirm(`Delete ${p.fullName}? This cannot be undone.`)) return;
    try { await dispatch(deleteUser(p.userId)).unwrap(); setMsg(''); load(); } catch (e) { setMsg(String(e)); }
  };

  return (
    <Page title="Patients" actions={<button className="btn" onClick={() => setEditing('new')}>+ Add patient</button>}>
      <div className="toolbar"><input placeholder="Search name, email, phone…" value={q} onChange={(e) => setQ(e.target.value)} /></div>
      <FormError msg={msg} />
      <Table loading={loading} rows={rows} cols={[
        { header: 'Name', cell: (p) => p.fullName },
        { header: 'Email', cell: (p) => p.email },
        { header: 'Phone', cell: (p) => p.phone ?? '—' },
        { header: 'DOB', cell: (p) => d10(p.dateOfBirth) || '—' },
        { header: 'Gender', cell: (p) => p.gender ?? '—' },
        { header: 'Blood', cell: (p) => p.bloodGroup ?? '—' },
        { header: 'Status', cell: (p) => <Badge text={activeOf(p.userId) ? 'Active' : 'Inactive'} /> },
        { header: '', cell: (p) => (
          <div className="row">
            <button className="btn ghost sm" onClick={() => setEditing(p)}>Edit</button>
            <button className="btn ghost sm" onClick={() => toggle(p)}>{activeOf(p.userId) ? 'Deactivate' : 'Activate'}</button>
            <button className="btn danger sm" onClick={() => remove(p)}>Delete</button>
          </div>) },
      ]} />
      {editing && <PatientForm patient={editing === 'new' ? undefined : editing} onClose={() => setEditing(null)} onSaved={load} />}
    </Page>
  );
}
