import { useState, type FormEvent } from 'react';
import { useAppDispatch, useAppSelector } from '../app/hooks';
import { login } from '../features/authSlice';
import { FormError } from '../components/ui';

export default function Login() {
  const dispatch = useAppDispatch();
  const { loading, error } = useAppSelector((s) => s.auth);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  const submit = (e: FormEvent) => { e.preventDefault(); dispatch(login({ email, password })); };

  return (
    <div className="login">
      <form className="card" onSubmit={submit}>
        <img src="/swasthya_logo.png" alt="Swasthya Hospital" style={{ display: 'block', width: 200, margin: '0 auto 12px' }} />
        <p className="muted" style={{ marginTop: 0 }}>Sign in as Admin or Pharmacist</p>
        <label className="field"><span>Email</span><input type="email" required value={email} onChange={(e) => setEmail(e.target.value)} /></label>
        <label className="field"><span>Password</span><input type="password" required value={password} onChange={(e) => setPassword(e.target.value)} /></label>
        <FormError msg={error ?? ''} />
        <button className="btn" style={{ width: '100%' }} disabled={loading}>{loading ? 'Signing in…' : 'Sign in'}</button>
      </form>
    </div>
  );
}
