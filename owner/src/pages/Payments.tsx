import { useEffect, useState } from 'react';
import { useAppDispatch, useAppSelector } from '../app/hooks';
import { collectCod, fetchPayments } from '../features/hospitalSlice';
import { Badge, FormError, Page, Table, dt, money } from '../components/ui';

export default function Payments() {
  const dispatch = useAppDispatch();
  const { payments, loading } = useAppSelector((s) => s.hospital);
  const [filter, setFilter] = useState('');
  const [msg, setMsg] = useState('');
  useEffect(() => { dispatch(fetchPayments()); }, [dispatch]);

  const rows = payments.filter((p) => !filter || p.status === filter);
  const total = rows.filter((p) => p.status === 'Success').reduce((a, p) => a + p.amount, 0);

  return (
    <Page title="Payments" actions={<span className="muted">Collected: <strong>{money(total)}</strong></span>}>
      <div className="toolbar">
        <select value={filter} onChange={(e) => setFilter(e.target.value)}>
          <option value="">All statuses</option>{['Pending', 'Success', 'Failed', 'Cancelled'].map((s) => <option key={s}>{s}</option>)}
        </select>
      </div>
      <FormError msg={msg} />
      <Table loading={loading} rows={rows} cols={[
        { header: '#', cell: (p) => p.id },
        { header: 'Date', cell: (p) => dt(p.createdAt) },
        { header: 'Patient', cell: (p) => p.patientName },
        { header: 'Doctor', cell: (p) => p.doctorName },
        { header: 'Amount', cell: (p) => money(p.amount) },
        { header: 'Method', cell: (p) => p.method },
        { header: 'Status', cell: (p) => <Badge text={p.status} /> },
        { header: '', cell: (p) => p.method === 'COD' && p.status !== 'Success' && (
          <button className="btn sm" onClick={async () => { try { await dispatch(collectCod(p.id)).unwrap(); setMsg(''); dispatch(fetchPayments()); } catch (e) { setMsg(String(e)); } }}>Mark collected</button>) },
      ]} />
    </Page>
  );
}
