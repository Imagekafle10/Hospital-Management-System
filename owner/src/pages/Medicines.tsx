import { useEffect, useState, type FormEvent } from 'react';
import { useAppDispatch, useAppSelector } from '../app/hooks';
import { deleteMedicine, fetchMedicines, restockMedicine, saveMedicine } from '../features/pharmacySlice';
import { Badge, Field, FormActions, FormError, Modal, Page, Table, d10, money, opt, optNum, useForm, useSubmit } from '../components/ui';
import type { Medicine } from '../types';

function stockBadge(m: Medicine) {
  if (!m.isActive) return 'Inactive';
  if (m.isExpired) return 'Expired';
  if (m.isLowStock) return 'Low';
  if (m.expiryDate && new Date(m.expiryDate).getTime() <= Date.now() + 90 * 864e5) return 'Expiring';
  return 'OK';
}

function MedicineForm({ med, onClose, onSaved }: { med?: Medicine; onClose: () => void; onSaved: () => void }) {
  const dispatch = useAppDispatch();
  const { busy, err, run } = useSubmit();
  const f = useForm({
    name: med?.name ?? '', genericName: med?.genericName ?? '', category: med?.category ?? '', manufacturer: med?.manufacturer ?? '',
    batchNumber: med?.batchNumber ?? '', unit: med?.unit ?? 'Tablet', unitPrice: String(med?.unitPrice ?? ''),
    stockQuantity: '0', reorderLevel: String(med?.reorderLevel ?? 10), expiryDate: d10(med?.expiryDate),
  });

  const submit = (e: FormEvent) => {
    e.preventDefault();
    const v = f.v;
    const data = {
      name: v.name, genericName: opt(v.genericName), category: opt(v.category), manufacturer: opt(v.manufacturer),
      batchNumber: opt(v.batchNumber), unit: v.unit, unitPrice: optNum(v.unitPrice) ?? 0,
      reorderLevel: optNum(v.reorderLevel) ?? 0, expiryDate: opt(v.expiryDate),
      ...(med ? {} : { stockQuantity: optNum(v.stockQuantity) ?? 0 }),
    };
    run(() => dispatch(saveMedicine({ id: med?.id, data })).unwrap(), () => { onSaved(); onClose(); });
  };

  return (
    <Modal title={med ? 'Edit medicine' : 'Add medicine'} onClose={onClose}>
      <form onSubmit={submit}>
        <div className="grid2">
          <Field label="Name" required {...f.bind('name')} />
          <Field label="Generic name" {...f.bind('genericName')} />
          <Field label="Category" placeholder="Antibiotic, Painkiller…" {...f.bind('category')} />
          <Field label="Manufacturer" {...f.bind('manufacturer')} />
          <Field label="Unit" placeholder="Tablet, Syrup, Injection…" required {...f.bind('unit')} />
          <Field label="Unit price (Rs.)" type="number" min="0" step="0.01" required {...f.bind('unitPrice')} />
          {!med && <Field label="Opening stock" type="number" min="0" {...f.bind('stockQuantity')} />}
          <Field label="Reorder level" type="number" min="0" {...f.bind('reorderLevel')} />
          <Field label="Batch number" {...f.bind('batchNumber')} />
          <Field label="Expiry date" type="date" {...f.bind('expiryDate')} />
        </div>
        <FormError msg={err} /><FormActions busy={busy} onCancel={onClose} />
      </form>
    </Modal>
  );
}

function RestockForm({ med, onClose, onSaved }: { med: Medicine; onClose: () => void; onSaved: () => void }) {
  const dispatch = useAppDispatch();
  const { busy, err, run } = useSubmit();
  const f = useForm({ quantity: '', batchNumber: '', expiryDate: '' });
  return (
    <Modal title={`Adjust stock — ${med.name}`} onClose={onClose}>
      <p className="muted">Current stock: <strong>{med.stockQuantity} {med.unit}</strong>. Use a negative number to write off damaged/expired stock.</p>
      <form onSubmit={(e) => { e.preventDefault(); run(() => dispatch(restockMedicine({ id: med.id, quantity: Number(f.v.quantity), batchNumber: opt(f.v.batchNumber), expiryDate: opt(f.v.expiryDate) })).unwrap(), () => { onSaved(); onClose(); }); }}>
        <Field label="Quantity (+ add / − remove)" type="number" required {...f.bind('quantity')} />
        <div className="grid2">
          <Field label="New batch number (optional)" {...f.bind('batchNumber')} />
          <Field label="New expiry (optional)" type="date" {...f.bind('expiryDate')} />
        </div>
        <FormError msg={err} /><FormActions busy={busy} onCancel={onClose} label="Update stock" />
      </form>
    </Modal>
  );
}

export default function Medicines() {
  const dispatch = useAppDispatch();
  const { medicines, loading } = useAppSelector((s) => s.pharmacy);
  const [search, setSearch] = useState('');
  const [lowStock, setLow] = useState(false);
  const [expiring, setExp] = useState(false);
  const [inactive, setInactive] = useState(false);
  const [editing, setEditing] = useState<Medicine | 'new' | null>(null);
  const [restock, setRestock] = useState<Medicine | null>(null);
  const [msg, setMsg] = useState('');

  const load = () => { dispatch(fetchMedicines({ search, lowStock, expiring, includeInactive: inactive })); };
  useEffect(() => { const t = setTimeout(load, 250); return () => clearTimeout(t); }, [search, lowStock, expiring, inactive]); // eslint-disable-line

  return (
    <Page title="Medicines & Stock" actions={<button className="btn" onClick={() => setEditing('new')}>+ Add medicine</button>}>
      <div className="toolbar">
        <input placeholder="Search name or generic…" value={search} onChange={(e) => setSearch(e.target.value)} />
        <label className="row"><input type="checkbox" style={{ width: 'auto' }} checked={lowStock} onChange={(e) => setLow(e.target.checked)} />Low stock</label>
        <label className="row"><input type="checkbox" style={{ width: 'auto' }} checked={expiring} onChange={(e) => setExp(e.target.checked)} />Expired / expiring</label>
        <label className="row"><input type="checkbox" style={{ width: 'auto' }} checked={inactive} onChange={(e) => setInactive(e.target.checked)} />Show inactive</label>
      </div>
      <FormError msg={msg} />
      <Table loading={loading} rows={medicines} cols={[
        { header: 'Medicine', cell: (m) => <>{m.name}<div className="muted">{m.genericName}</div></> },
        { header: 'Category', cell: (m) => m.category ?? '—' },
        { header: 'Price', cell: (m) => `${money(m.unitPrice)} / ${m.unit}` },
        { header: 'Stock', cell: (m) => `${m.stockQuantity} (min ${m.reorderLevel})` },
        { header: 'Batch', cell: (m) => m.batchNumber ?? '—' },
        { header: 'Expiry', cell: (m) => d10(m.expiryDate) || '—' },
        { header: 'Status', cell: (m) => <Badge text={stockBadge(m)} /> },
        { header: '', cell: (m) => (
          <div className="row">
            <button className="btn ghost sm" onClick={() => setRestock(m)}>Stock</button>
            <button className="btn ghost sm" onClick={() => setEditing(m)}>Edit</button>
            <button className="btn danger sm" onClick={async () => { if (!confirm(`Delete ${m.name}?`)) return; try { await dispatch(deleteMedicine(m.id)).unwrap(); setMsg(''); load(); } catch (e) { setMsg(String(e)); } }}>Delete</button>
          </div>) },
      ]} />
      {editing && <MedicineForm med={editing === 'new' ? undefined : editing} onClose={() => setEditing(null)} onSaved={load} />}
      {restock && <RestockForm med={restock} onClose={() => setRestock(null)} onSaved={load} />}
    </Page>
  );
}
