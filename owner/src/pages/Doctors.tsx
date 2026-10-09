import { useEffect, useState, type FormEvent } from 'react';
import { photoUrl } from '../api/client';
import { useAppDispatch, useAppSelector } from '../app/hooks';
import { createUser, deleteUser, fetchDoctors, fetchUsers, updateDoctor, updateUser } from '../features/usersSlice';
import { Badge, Field, FormActions, FormError, Modal, Page, Table, money, opt, optNum, useForm, useSubmit } from '../components/ui';
import type { Doctor } from '../types';

const hhmm = (t?: string | null) => (t ? t.slice(0, 5) : '');
const toSpan = (t: string) => (t ? `${t}:00` : undefined);

function DoctorForm({ doctor, onClose, onSaved }: { doctor?: Doctor; onClose: () => void; onSaved: () => void }) {
  const dispatch = useAppDispatch();
  const { busy, err, run } = useSubmit();
  const f = useForm({
    fullName: doctor?.fullName ?? '', email: doctor?.email ?? '', phone: doctor?.phone ?? '', password: '',
    specialization: doctor?.specialization ?? '', licenseNumber: doctor?.licenseNumber ?? '',
    consultationFee: String(doctor?.consultationFee ?? ''), yearsOfExperience: String(doctor?.yearsOfExperience ?? ''),
    availableFrom: hhmm(doctor?.availableFrom), availableTo: hhmm(doctor?.availableTo),
  });

  const submit = (e: FormEvent) => {
    e.preventDefault();
    const v = f.v;
    run(async () => {
      if (doctor) {
        await dispatch(updateDoctor({ id: doctor.id, data: {
          fullName: v.fullName, email: v.email, phone: opt(v.phone), newPassword: opt(v.password),
          specialization: v.specialization, licenseNumber: v.licenseNumber, consultationFee: optNum(v.consultationFee),
          yearsOfExperience: optNum(v.yearsOfExperience), availableFrom: toSpan(v.availableFrom), availableTo: toSpan(v.availableTo),
        } })).unwrap();
      } else {
        await dispatch(createUser({
          role: 'Doctor', fullName: v.fullName, email: v.email, password: v.password, phone: opt(v.phone),
          specialization: v.specialization, licenseNumber: v.licenseNumber,
          consultationFee: optNum(v.consultationFee), yearsOfExperience: optNum(v.yearsOfExperience),
        })).unwrap();
      }
    }, () => { onSaved(); onClose(); });
  };

  return (
    <Modal title={doctor ? 'Edit doctor' : 'Add doctor'} onClose={onClose}>
      <form onSubmit={submit}>
        <div className="grid2">
          <Field label="Full name" required {...f.bind('fullName')} />
          <Field label="Email" type="email" required {...f.bind('email')} />
          <Field label="Phone" {...f.bind('phone')} />
          <Field label={doctor ? 'New password (optional)' : 'Password'} type="password" required={!doctor} {...f.bind('password')} />
          <Field label="Specialization" required {...f.bind('specialization')} />
          <Field label="License number" required {...f.bind('licenseNumber')} />
          <Field label="Consultation fee" type="number" min="0" step="0.01" {...f.bind('consultationFee')} />
          <Field label="Years of experience" type="number" min="0" {...f.bind('yearsOfExperience')} />
          {doctor && <Field label="Available from" type="time" {...f.bind('availableFrom')} />}
          {doctor && <Field label="Available to" type="time" {...f.bind('availableTo')} />}
        </div>
        <FormError msg={err} />
        <FormActions busy={busy} onCancel={onClose} />
      </form>
    </Modal>
  );
}

export default function Doctors() {
  const dispatch = useAppDispatch();
  const { doctors, users, loading } = useAppSelector((s) => s.users);
  const [q, setQ] = useState('');
  const [editing, setEditing] = useState<Doctor | 'new' | null>(null);
  const [msg, setMsg] = useState('');

  const load = () => { dispatch(fetchDoctors()); dispatch(fetchUsers()); };
  useEffect(load, [dispatch]);

  const activeOf = (userId: number) => users.find((u) => u.id === userId)?.isActive ?? true;
  const rows = doctors.filter((d) => `${d.fullName} ${d.specialization} ${d.email}`.toLowerCase().includes(q.toLowerCase()));

  const toggle = async (d: Doctor) => {
    try { await dispatch(updateUser({ id: d.userId, data: { isActive: !activeOf(d.userId) } })).unwrap(); load(); } catch (e) { setMsg(String(e)); }
  };
  const remove = async (d: Doctor) => {
    if (!confirm(`Delete Dr. ${d.fullName}? This cannot be undone.`)) return;
    try { await dispatch(deleteUser(d.userId)).unwrap(); setMsg(''); load(); } catch (e) { setMsg(String(e)); }
  };

  return (
    <Page title="Doctors" actions={<button className="btn" onClick={() => setEditing('new')}>+ Add doctor</button>}>
      <div className="toolbar"><input placeholder="Search name, specialization…" value={q} onChange={(e) => setQ(e.target.value)} /></div>
      <FormError msg={msg} />
      <Table loading={loading} rows={rows} cols={[
        { header: 'Doctor', cell: (d) => (<><img className="avatar" src={photoUrl(d.id)} alt="" onError={(e) => { e.currentTarget.style.visibility = 'hidden'; }} />{d.fullName}</>) },
        { header: 'Specialization', cell: (d) => d.specialization },
        { header: 'License', cell: (d) => d.licenseNumber },
        { header: 'Fee', cell: (d) => money(d.consultationFee) },
        { header: 'Exp.', cell: (d) => `${d.yearsOfExperience} yrs` },
        { header: 'Hours', cell: (d) => (d.availableFrom ? `${hhmm(d.availableFrom)}–${hhmm(d.availableTo)}` : '—') },
        { header: 'Status', cell: (d) => <Badge text={activeOf(d.userId) ? 'Active' : 'Inactive'} /> },
        { header: '', cell: (d) => (
          <div className="row">
            <button className="btn ghost sm" onClick={() => setEditing(d)}>Edit</button>
            <button className="btn ghost sm" onClick={() => toggle(d)}>{activeOf(d.userId) ? 'Deactivate' : 'Activate'}</button>
            <button className="btn danger sm" onClick={() => remove(d)}>Delete</button>
          </div>) },
      ]} />
      {editing && <DoctorForm doctor={editing === 'new' ? undefined : editing} onClose={() => setEditing(null)} onSaved={load} />}
    </Page>
  );
}
