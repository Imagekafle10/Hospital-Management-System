import { useEffect, useState } from 'react';
import { useAppDispatch, useAppSelector } from '../app/hooks';
import { fetchAppointments, setAppointmentStatus } from '../features/hospitalSlice';
import { Badge, FormError, Page, Table, dt } from '../components/ui';

const STATUSES = ['Pending', 'Confirmed', 'Completed', 'Cancelled'];

export default function Appointments() {
  const dispatch = useAppDispatch();
  const { appointments, loading } = useAppSelector((s) => s.hospital);
  const [filter, setFilter] = useState('');
  const [msg, setMsg] = useState('');

  useEffect(() => { dispatch(fetchAppointments()); }, [dispatch]);

  const change = async (id: number, status: string) => {
    try { await dispatch(setAppointmentStatus({ id, status })).unwrap(); setMsg(''); dispatch(fetchAppointments()); } catch (e) { setMsg(String(e)); }
  };
  const rows = appointments.filter((a) => !filter || a.status === filter);

  return (
    <Page title="Appointments">
      <div className="toolbar">
        <select value={filter} onChange={(e) => setFilter(e.target.value)}>
          <option value="">All statuses</option>{STATUSES.map((s) => <option key={s}>{s}</option>)}
        </select>
      </div>
      <FormError msg={msg} />
      <Table loading={loading} rows={rows} cols={[
        { header: '#', cell: (a) => a.id },
        { header: 'When', cell: (a) => dt(a.appointmentDate) },
        { header: 'Patient', cell: (a) => a.patientName },
        { header: 'Doctor', cell: (a) => `${a.doctorName} (${a.doctorSpecialization ?? ''})` },
        { header: 'Reason', cell: (a) => a.reason ?? '—' },
        { header: 'Status', cell: (a) => <Badge text={a.status} /> },
        { header: 'Change status', cell: (a) => (
          <select value={a.status} onChange={(e) => change(a.id, e.target.value)}>{STATUSES.map((s) => <option key={s}>{s}</option>)}</select>) },
      ]} />
    </Page>
  );
}
