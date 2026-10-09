import { useEffect, useState } from 'react';
import { useAppDispatch, useAppSelector } from '../app/hooks';
import { fetchDispenses } from '../features/pharmacySlice';
import { Page, Table, dt, money } from '../components/ui';

export default function DispenseHistory() {
  const dispatch = useAppDispatch();
  const { dispenses, loading } = useAppSelector((s) => s.pharmacy);
  const [q, setQ] = useState('');
  useEffect(() => { dispatch(fetchDispenses()); }, [dispatch]);

  const rows = dispenses.filter((d) => `${d.patientName} ${d.medicineName}`.toLowerCase().includes(q.toLowerCase()));
  return (
    <Page title="Dispense history" actions={<span className="muted">Total: <strong>{money(rows.reduce((a, d) => a + d.totalPrice, 0))}</strong></span>}>
      <div className="toolbar"><input placeholder="Search patient or medicine…" value={q} onChange={(e) => setQ(e.target.value)} /></div>
      <Table loading={loading} rows={rows} cols={[
        { header: 'Date', cell: (d) => dt(d.createdAt) },
        { header: 'Patient', cell: (d) => d.patientName },
        { header: 'Medicine', cell: (d) => d.medicineName },
        { header: 'Qty', cell: (d) => d.quantity },
        { header: 'Unit price', cell: (d) => money(d.unitPrice) },
        { header: 'Total', cell: (d) => money(d.totalPrice) },
        { header: 'Rx', cell: (d) => (d.prescriptionId ? `#${d.prescriptionId}` : '—') },
        { header: 'Notes', cell: (d) => d.notes ?? '—' },
      ]} />
    </Page>
  );
}
