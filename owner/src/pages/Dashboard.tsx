import { useEffect } from 'react';
import { useAppDispatch, useAppSelector } from '../app/hooks';
import { fetchStats } from '../features/usersSlice';
import { fetchDispenses, fetchMedicines } from '../features/pharmacySlice';
import { Page, Stat, money } from '../components/ui';

export default function Dashboard() {
  const dispatch = useAppDispatch();
  const role = useAppSelector((s) => s.auth.user!.role);
  const stats = useAppSelector((s) => s.users.stats);
  const { medicines, dispenses } = useAppSelector((s) => s.pharmacy);

  useEffect(() => {
    if (role === 'Admin') dispatch(fetchStats());
    dispatch(fetchMedicines({})); dispatch(fetchDispenses());
  }, [dispatch, role]);

  const soon = Date.now() + 90 * 864e5;
  const low = medicines.filter((m) => m.isLowStock).length;
  const expiring = medicines.filter((m) => m.expiryDate && new Date(m.expiryDate).getTime() <= soon).length;
  const today = new Date().toDateString();
  const todaySales = dispenses.filter((d) => new Date(d.createdAt).toDateString() === today).reduce((a, d) => a + d.totalPrice, 0);

  return (
    <Page title="Dashboard">
      {role === 'Admin' && stats && (
        <>
          <h2 style={{ margin: '0 0 10px' }}>Hospital</h2>
          <div className="stats" style={{ marginBottom: 24 }}>
            <Stat label="Patients" value={stats.patients} />
            <Stat label="Doctors" value={stats.doctors} />
            <Stat label="Pharmacists" value={stats.pharmacists} />
            <Stat label="Appointments" value={stats.appointments} />
            <Stat label="Pending appointments" value={stats.pendingAppointments} tone={stats.pendingAppointments ? 'warn' : ''} />
            <Stat label="Admitted now" value={stats.activeAdmissions} />
            <Stat label="Beds available" value={`${stats.availableBeds} / ${stats.totalBeds}`} />
            <Stat label="Consultation revenue" value={money(stats.revenue)} />
          </div>
        </>
      )}
      <h2 style={{ margin: '0 0 10px' }}>Pharmacy</h2>
      <div className="stats">
        <Stat label="Medicines" value={medicines.length} />
        <Stat label="Low stock" value={low} tone={low ? 'warn' : ''} />
        <Stat label="Expired / expiring (90d)" value={expiring} tone={expiring ? 'bad' : ''} />
        <Stat label="Sales today" value={money(todaySales)} />
        <Stat label="Total pharmacy sales" value={money(dispenses.reduce((a, d) => a + d.totalPrice, 0))} />
      </div>
    </Page>
  );
}
