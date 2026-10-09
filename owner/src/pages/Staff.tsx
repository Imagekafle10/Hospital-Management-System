import { useEffect, useState, type FormEvent } from 'react';
import { useAppDispatch, useAppSelector } from '../app/hooks';
import { createUser, deleteUser, fetchUsers, updateUser } from '../features/usersSlice';
import { Badge, Field, FormActions, FormError, Modal, Page, Select, Table, opt, useForm, useSubmit } from '../components/ui';
import type { StaffUser } from '../types';

const ROLES = [{ value: 'Pharmacist', label: 'Pharmacist' }, { value: 'Admin', label: 'Admin' }];

function StaffForm({ user, onClose, onSaved }: { user?: StaffUser; onClose: () => void; onSaved: () => void }) {
  const dispatch = useAppDispatch();
  const { busy, err, run } = useSubmit();
  const f = useForm({ fullName: user?.fullName ?? '', email: user?.email ?? '', phone: user?.phone ?? '', password: '', role: user?.role ?? 'Pharmacist' });

  const submit = (e: FormEvent) => {
    e.preventDefault();
    const v = f.v;
    run(async () => {
      if (user) await dispatch(updateUser({ id: user.id, data: { fullName: v.fullName, email: v.email, phone: opt(v.phone), newPassword: opt(v.password) } })).unwrap();
      else await dispatch(createUser({ fullName: v.fullName, email: v.email, phone: opt(v.phone), password: v.password, role: v.role })).unwrap();
    }, () => { onSaved(); onClose(); });
  };

  return (
    <Modal title={user ? 'Edit staff account' : 'Add staff account'} onClose={onClose}>
      <form onSubmit={submit}>
        <div className="grid2">
          <Field label="Full name" required {...f.bind('fullName')} />
          <Field label="Email" type="email" required {...f.bind('email')} />
          <Field label="Phone" {...f.bind('phone')} />
          <Field label={user ? 'New password (optional)' : 'Password'} type="password" required={!user} {...f.bind('password')} />
          {!user && <Select label="Role" required options={ROLES} {...f.bind('role')} />}
        </div>
        <FormError msg={err} />
        <FormActions busy={busy} onCancel={onClose} />
      </form>
    </Modal>
  );
}

export default function Staff() {
  const dispatch = useAppDispatch();
  const { users, loading } = useAppSelector((s) => s.users);
  const me = useAppSelector((s) => s.auth.user!.userId);
  const [editing, setEditing] = useState<StaffUser | 'new' | null>(null);
  const [msg, setMsg] = useState('');

  const load = () => { dispatch(fetchUsers()); };
  useEffect(load, [dispatch]);
  const staff = users.filter((u) => u.role === 'Admin' || u.role === 'Pharmacist');

  const act = async (fn: () => Promise<unknown>) => { try { await fn(); setMsg(''); load(); } catch (e) { setMsg(String(e)); } };

  return (
    <Page title="Staff & Pharmacists" actions={<button className="btn" onClick={() => setEditing('new')}>+ Add account</button>}>
      <FormError msg={msg} />
      <Table loading={loading} rows={staff} cols={[
        { header: 'Name', cell: (u) => u.fullName },
        { header: 'Email', cell: (u) => u.email },
        { header: 'Phone', cell: (u) => u.phone ?? '—' },
        { header: 'Role', cell: (u) => <Badge text={u.role} /> },
        { header: 'Status', cell: (u) => <Badge text={u.isActive ? 'Active' : 'Inactive'} /> },
        { header: '', cell: (u) => (
          <div className="row">
            <button className="btn ghost sm" onClick={() => setEditing(u)}>Edit</button>
            {u.id !== me && <>
              <button className="btn ghost sm" onClick={() => act(() => dispatch(updateUser({ id: u.id, data: { isActive: !u.isActive } })).unwrap())}>{u.isActive ? 'Deactivate' : 'Activate'}</button>
              <button className="btn danger sm" onClick={() => confirm(`Delete ${u.fullName}?`) && act(() => dispatch(deleteUser(u.id)).unwrap())}>Delete</button>
            </>}
          </div>) },
      ]} />
      {editing && <StaffForm user={editing === 'new' ? undefined : editing} onClose={() => setEditing(null)} onSaved={load} />}
    </Page>
  );
}
