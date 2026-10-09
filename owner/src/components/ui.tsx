import { useState, type ChangeEvent, type ReactNode } from 'react';

export function Page({ title, actions, children }: { title: string; actions?: ReactNode; children: ReactNode }) {
  return (
    <div>
      <div className="page-head"><h1>{title}</h1><div className="row">{actions}</div></div>
      {children}
    </div>
  );
}

export function Modal({ title, onClose, children }: { title: string; onClose: () => void; children: ReactNode }) {
  return (
    <div className="overlay" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div className="modal">
        <div className="modal-head"><h2>{title}</h2><button className="icon" onClick={onClose} aria-label="Close">×</button></div>
        {children}
      </div>
    </div>
  );
}

export interface Col<T> { header: string; cell: (r: T) => ReactNode }
export function Table<T>({ rows, cols, loading }: { rows: T[]; cols: Col<T>[]; loading?: boolean }) {
  return (
    <div className="card table-wrap">
      <table>
        <thead><tr>{cols.map((c) => <th key={c.header}>{c.header}</th>)}</tr></thead>
        <tbody>
          {rows.map((r, i) => <tr key={i}>{cols.map((c) => <td key={c.header}>{c.cell(r)}</td>)}</tr>)}
          {rows.length === 0 && <tr><td colSpan={cols.length} className="muted center">{loading ? 'Loading…' : 'Nothing here yet.'}</td></tr>}
        </tbody>
      </table>
    </div>
  );
}

const TONES: Record<string, string> = {
  Pending: 'warn', Confirmed: 'info', Completed: 'ok', Cancelled: 'bad', Success: 'ok', Failed: 'bad',
  Admitted: 'info', Discharged: 'ok', Available: 'ok', Occupied: 'bad', Maintenance: 'warn',
  Active: 'ok', Inactive: 'bad', Low: 'warn', Expired: 'bad', Expiring: 'warn', OK: 'ok',
};
export const Badge = ({ text }: { text: string }) => <span className={`badge ${TONES[text] ?? 'info'}`}>{text}</span>;

type FieldProps = { label: string; value: string; onChange: (e: ChangeEvent<HTMLInputElement & HTMLSelectElement & HTMLTextAreaElement>) => void };
export function Field({ label, type = 'text', required, ...p }: FieldProps & { type?: string; required?: boolean; min?: string; step?: string; placeholder?: string }) {
  return <label className="field"><span>{label}{required && ' *'}</span><input type={type} required={required} {...p} /></label>;
}
export function TextArea({ label, ...p }: FieldProps & { rows?: number }) {
  return <label className="field"><span>{label}</span><textarea rows={3} {...p} /></label>;
}
export function Select({ label, options, required, ...p }: FieldProps & { options: { value: string | number; label: string }[]; required?: boolean }) {
  return (
    <label className="field"><span>{label}{required && ' *'}</span>
      <select required={required} {...p}>
        <option value="">— select —</option>
        {options.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
      </select>
    </label>
  );
}

// Tiny form-state helper: const f = useForm({a:''}); <Field {...f.bind('a')} label="A" />
export function useForm<T extends Record<string, string>>(initial: T) {
  const [v, setV] = useState<T>(initial);
  return {
    v, setV,
    bind: (k: keyof T & string) => ({ value: v[k] ?? '', onChange: (e: ChangeEvent<HTMLInputElement & HTMLSelectElement & HTMLTextAreaElement>) => setV((p) => ({ ...p, [k]: e.target.value })) }),
  };
}

// Runs an async action (usually dispatch(thunk).unwrap()) and tracks busy/error for the form.
export function useSubmit() {
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState('');
  const run = async (fn: () => Promise<unknown>, onDone?: () => void) => {
    setBusy(true); setErr('');
    try { await fn(); onDone?.(); } catch (e) { setErr(typeof e === 'string' ? e : e instanceof Error ? e.message : 'Failed'); } finally { setBusy(false); }
  };
  return { busy, err, setErr, run };
}

export const FormError = ({ msg }: { msg: string }) => (msg ? <div className="alert">{msg}</div> : null);
export const FormActions = ({ busy, onCancel, label = 'Save' }: { busy: boolean; onCancel: () => void; label?: string }) => (
  <div className="row end"><button type="button" className="btn ghost" onClick={onCancel}>Cancel</button><button className="btn" disabled={busy}>{busy ? 'Please wait…' : label}</button></div>
);

export const Stat = ({ label, value, tone }: { label: string; value: string | number; tone?: string }) => (
  <div className={`card stat ${tone ?? ''}`}><div className="muted">{label}</div><div className="num">{value}</div></div>
);

export const d10 = (s?: string | null) => (s ? s.slice(0, 10) : '');
export const dt = (s?: string | null) => (s ? new Date(s).toLocaleString() : '—');
export const money = (n: number) => `Rs. ${Number(n).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
export const opt = (s: string) => (s.trim() === '' ? undefined : s.trim());
export const optNum = (s: string) => (s.trim() === '' ? undefined : Number(s));
