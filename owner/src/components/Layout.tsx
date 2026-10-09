import { NavLink, Outlet } from 'react-router-dom';
import { useAppDispatch, useAppSelector } from '../app/hooks';
import { logout } from '../features/authSlice';

const ADMIN_NAV = [
  ['/', 'Dashboard'], ['/patients', 'Patients'], ['/doctors', 'Doctors'], ['/staff', 'Staff & Pharmacists'],
  ['/appointments', 'Appointments'], ['/wards', 'Wards & Beds'], ['/admissions', 'Admissions'], ['/payments', 'Payments'],
  ['/pharmacy/medicines', 'Pharmacy · Medicines'], ['/pharmacy/dispense', 'Pharmacy · Dispense'], ['/pharmacy/history', 'Pharmacy · History'],
];
const PHARMACY_NAV = [
  ['/', 'Dashboard'], ['/pharmacy/medicines', 'Medicines & Stock'], ['/pharmacy/dispense', 'Dispense'], ['/pharmacy/history', 'Dispense History'],
];

export default function Layout() {
  const user = useAppSelector((s) => s.auth.user)!;
  const dispatch = useAppDispatch();
  const nav = user.role === 'Admin' ? ADMIN_NAV : PHARMACY_NAV;
  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">
          <img src="/swasthya_mark.png" alt="" />
          <div><strong>Swasthya</strong><small>{user.role === 'Admin' ? 'Admin Panel' : 'Pharmacy Panel'}</small></div>
        </div>
        <nav>{nav.map(([to, label]) => <NavLink key={to} to={to} end={to === '/'}>{label}</NavLink>)}</nav>
      </aside>
      <div className="main">
        <header className="topbar">
          <span className="muted">{user.role}</span>
          <strong>{user.fullName}</strong>
          <button className="btn ghost" onClick={() => dispatch(logout())}>Log out</button>
        </header>
        <main className="content"><Outlet /></main>
      </div>
    </div>
  );
}
