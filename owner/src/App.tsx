import { useEffect } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import { useAppDispatch, useAppSelector } from './app/hooks';
import { logout } from './features/authSlice';
import Layout from './components/Layout';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Patients from './pages/Patients';
import Doctors from './pages/Doctors';
import Staff from './pages/Staff';
import Appointments from './pages/Appointments';
import Wards from './pages/Wards';
import Admissions from './pages/Admissions';
import Payments from './pages/Payments';
import Medicines from './pages/Medicines';
import Dispense from './pages/Dispense';
import DispenseHistory from './pages/DispenseHistory';

export default function App() {
  const dispatch = useAppDispatch();
  const user = useAppSelector((s) => s.auth.user);

  // api client fires this on any 401 (expired / invalid token)
  useEffect(() => {
    const h = () => dispatch(logout());
    window.addEventListener('hms-unauthorized', h);
    return () => window.removeEventListener('hms-unauthorized', h);
  }, [dispatch]);

  if (!user) return <Login />;

  return (
    <Routes>
      <Route element={<Layout />}>
        <Route index element={<Dashboard />} />
        {user.role === 'Admin' && (
          <>
            <Route path="patients" element={<Patients />} />
            <Route path="doctors" element={<Doctors />} />
            <Route path="staff" element={<Staff />} />
            <Route path="appointments" element={<Appointments />} />
            <Route path="wards" element={<Wards />} />
            <Route path="admissions" element={<Admissions />} />
            <Route path="payments" element={<Payments />} />
          </>
        )}
        <Route path="pharmacy/medicines" element={<Medicines />} />
        <Route path="pharmacy/dispense" element={<Dispense />} />
        <Route path="pharmacy/history" element={<DispenseHistory />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  );
}
