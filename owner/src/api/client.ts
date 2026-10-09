const BASE: string = import.meta.env.VITE_API_URL ?? 'http://localhost:5000';

export class ApiError extends Error {
  status: number;
  constructor(message: string, status: number) { super(message); this.status = status; }
}

function extractMessage(text: string, fallback: string): string {
  if (!text) return fallback;
  try {
    const j = JSON.parse(text);
    if (typeof j === 'string') return j;
    if (j?.errors) return Object.values(j.errors as Record<string, string[]>).flat().join(' ');
    return j?.message ?? j?.title ?? fallback;
  } catch {
    return text;
  }
}

export async function api<T = void>(path: string, opts: { method?: string; body?: unknown } = {}): Promise<T> {
  const token = localStorage.getItem('hms_token');
  let res: Response;
  try {
    res = await fetch(BASE + path, {
      method: opts.method ?? 'GET',
      headers: {
        ...(opts.body !== undefined ? { 'Content-Type': 'application/json' } : {}),
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: opts.body !== undefined ? JSON.stringify(opts.body) : undefined,
    });
  } catch {
    throw new ApiError(`Cannot reach the server at ${BASE}`, 0);
  }
  if (res.status === 401 && token) window.dispatchEvent(new Event('hms-unauthorized'));
  const text = await res.text();
  if (!res.ok) throw new ApiError(extractMessage(text, res.status === 403 ? 'You do not have permission.' : res.statusText), res.status);
  return (text ? JSON.parse(text) : undefined) as T;
}

export const photoUrl = (doctorId: number) => `${BASE}/api/doctors/${doctorId}/photo`;
export const qs = (o: Record<string, string | boolean | undefined>) => {
  const p = Object.entries(o).filter(([, v]) => v !== undefined && v !== '' && v !== false).map(([k, v]) => `${k}=${encodeURIComponent(String(v))}`);
  return p.length ? `?${p.join('&')}` : '';
};
