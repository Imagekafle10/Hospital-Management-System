import { useEffect, useState, type FormEvent } from 'react';
import { useAppDispatch, useAppSelector } from '../app/hooks';
import { addBed, deleteBed, deleteWard, fetchBeds, fetchWards, saveWard, setBedStatus } from '../features/hospitalSlice';
import { Badge, Field, FormActions, FormError, Modal, Page, Select, Table, optNum, useForm, useSubmit } from '../components/ui';
import type { Ward } from '../types';

const TYPES = ['General', 'ICU', 'Private', 'Maternity', 'Emergency'].map((t) => ({ value: t, label: t }));

function WardForm({ ward, onClose, onSaved }: { ward?: Ward; onClose: () => void; onSaved: () => void }) {
  const dispatch = useAppDispatch();
  const { busy, err, run } = useSubmit();
  const f = useForm({ name: ward?.name ?? '', wardType: ward?.wardType ?? 'General', floorNumber: String(ward?.floorNumber ?? ''), description: ward?.description ?? '' });
  const submit = (e: FormEvent) => {
    e.preventDefault();
    run(() => dispatch(saveWard({ id: ward?.id, data: { name: f.v.name, wardType: f.v.wardType, floorNumber: optNum(f.v.floorNumber), description: f.v.description || undefined } })).unwrap(), () => { onSaved(); onClose(); });
  };
  return (
    <Modal title={ward ? 'Edit ward' : 'Add ward'} onClose={onClose}>
      <form onSubmit={submit}>
        <div className="grid2">
          <Field label="Name" required {...f.bind('name')} />
          <Select label="Type" required options={TYPES} {...f.bind('wardType')} />
          <Field label="Floor" type="number" {...f.bind('floorNumber')} />
          <Field label="Description" {...f.bind('description')} />
        </div>
        <FormError msg={err} /><FormActions busy={busy} onCancel={onClose} />
      </form>
    </Modal>
  );
}

function BedsModal({ ward, onClose, onChanged }: { ward: Ward; onClose: () => void; onChanged: () => void }) {
  const dispatch = useAppDispatch();
  const beds = useAppSelector((s) => s.hospital.beds).filter((b) => b.wardId === ward.id);
  const { busy, err, run } = useSubmit();
  const [num, setNum] = useState('');

  useEffect(() => { dispatch(fetchBeds(undefined)); }, [dispatch]);
  const refresh = () => { dispatch(fetchBeds(undefined)); onChanged(); };

  return (
    <Modal title={`Beds — ${ward.name}`} onClose={onClose}>
      <form className="row" onSubmit={(e) => { e.preventDefault(); run(() => dispatch(addBed({ wardId: ward.id, bedNumber: num })).unwrap(), () => { setNum(''); refresh(); }); }}>
        <input placeholder="New bed number e.g. B-101" required value={num} onChange={(e) => setNum(e.target.value)} style={{ flex: 1 }} />
        <button className="btn" disabled={busy}>Add bed</button>
      </form>
      <FormError msg={err} />
      <div style={{ marginTop: 12 }}>
        <Table rows={beds} cols={[
          { header: 'Bed', cell: (b) => b.bedNumber },
          { header: 'Status', cell: (b) => <Badge text={b.status} /> },
          { header: '', cell: (b) => (
            <div className="row">
              {b.status !== 'Occupied' && (
                <button className="btn ghost sm" onClick={() => run(() => dispatch(setBedStatus({ id: b.id, status: b.status === 'Available' ? 'Maintenance' : 'Available' })).unwrap(), refresh)}>
                  {b.status === 'Available' ? 'Set maintenance' : 'Set available'}</button>)}
              {b.status !== 'Occupied' && <button className="btn danger sm" onClick={() => run(() => dispatch(deleteBed(b.id)).unwrap(), refresh)}>Delete</button>}
            </div>) },
        ]} />
      </div>
    </Modal>
  );
}

export default function Wards() {
  const dispatch = useAppDispatch();
  const { wards, loading } = useAppSelector((s) => s.hospital);
  const [editing, setEditing] = useState<Ward | 'new' | null>(null);
  const [bedsFor, setBedsFor] = useState<Ward | null>(null);
  const [msg, setMsg] = useState('');
  const load = () => { dispatch(fetchWards()); };
  useEffect(load, [dispatch]);

  return (
    <Page title="Wards & Beds" actions={<button className="btn" onClick={() => setEditing('new')}>+ Add ward</button>}>
      <FormError msg={msg} />
      <Table loading={loading} rows={wards} cols={[
        { header: 'Ward', cell: (w) => w.name },
        { header: 'Type', cell: (w) => w.wardType },
        { header: 'Floor', cell: (w) => w.floorNumber ?? '—' },
        { header: 'Beds free / total', cell: (w) => `${w.availableBeds} / ${w.totalBeds}` },
        { header: 'Description', cell: (w) => w.description ?? '—' },
        { header: '', cell: (w) => (
          <div className="row">
            <button className="btn ghost sm" onClick={() => setBedsFor(w)}>Beds</button>
            <button className="btn ghost sm" onClick={() => setEditing(w)}>Edit</button>
            <button className="btn danger sm" onClick={async () => { if (!confirm(`Delete ${w.name}?`)) return; try { await dispatch(deleteWard(w.id)).unwrap(); setMsg(''); load(); } catch (e) { setMsg(String(e)); } }}>Delete</button>
          </div>) },
      ]} />
      {editing && <WardForm ward={editing === 'new' ? undefined : editing} onClose={() => setEditing(null)} onSaved={load} />}
      {bedsFor && <BedsModal ward={bedsFor} onClose={() => setBedsFor(null)} onChanged={load} />}
    </Page>
  );
}
