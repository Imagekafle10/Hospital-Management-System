import { useEffect, useState, type FormEvent } from 'react';
import { useAppDispatch, useAppSelector } from '../app/hooks';
import { clearPrescriptions, dispenseMedicine, fetchMedicines, fetchPrescriptions } from '../features/pharmacySlice';
import { fetchPatients } from '../features/usersSlice';
import { Field, FormError, Page, Select, TextArea, dt, money, useForm, useSubmit } from '../components/ui';

export default function Dispense() {
  const dispatch = useAppDispatch();
  const patients = useAppSelector((s) => s.users.patients);
  const { medicines, prescriptions } = useAppSelector((s) => s.pharmacy);
  const { busy, err, run } = useSubmit();
  const [ok, setOk] = useState('');
  const [rxId, setRxId] = useState<number | undefined>();
  const f = useForm({ patientId: '', medicineId: '', quantity: '1', notes: '' });

  useEffect(() => { dispatch(fetchPatients()); dispatch(fetchMedicines({})); return () => { dispatch(clearPrescriptions()); }; }, [dispatch]);
  useEffect(() => {
    setRxId(undefined);
    if (f.v.patientId) dispatch(fetchPrescriptions(Number(f.v.patientId))); else dispatch(clearPrescriptions());
  }, [f.v.patientId, dispatch]);

  const available = medicines.filter((m) => m.isActive && !m.isExpired && m.stockQuantity > 0);
  const med = medicines.find((m) => m.id === Number(f.v.medicineId));
  const qty = Number(f.v.quantity) || 0;

  // Clicking a prescription links it and pre-selects a medicine whose name matches.
  const useRx = (id: number, medication: string, dosage?: string | null) => {
    setRxId(id);
    const match = available.find((m) => medication.toLowerCase().includes(m.name.toLowerCase()) || (m.genericName && medication.toLowerCase().includes(m.genericName.toLowerCase())));
    f.setV((p) => ({ ...p, medicineId: match ? String(match.id) : p.medicineId, notes: p.notes || `${medication}${dosage ? ' — ' + dosage : ''}` }));
  };

  const submit = (e: FormEvent) => {
    e.preventDefault();
    setOk('');
    run(async () => {
      await dispatch(dispenseMedicine({ patientId: Number(f.v.patientId), medicineId: Number(f.v.medicineId), quantity: qty, prescriptionId: rxId, notes: f.v.notes || undefined })).unwrap();
      setOk(`Dispensed ${qty} × ${med?.name} for ${money((med?.unitPrice ?? 0) * qty)}.`);
      f.setV((p) => ({ ...p, medicineId: '', quantity: '1', notes: '' })); setRxId(undefined);
      dispatch(fetchMedicines({}));
    });
  };

  return (
    <Page title="Dispense medicine">
      <div className="grid2" style={{ alignItems: 'start' }}>
        <form className="card" style={{ padding: 20 }} onSubmit={submit}>
          <Select label="Patient" required options={patients.map((p) => ({ value: p.id, label: `${p.fullName} (${p.phone ?? p.email})` }))} {...f.bind('patientId')} />
          <Select label="Medicine" required options={available.map((m) => ({ value: m.id, label: `${m.name} — ${m.stockQuantity} ${m.unit} in stock` }))} {...f.bind('medicineId')} />
          <Field label="Quantity" type="number" min="1" required {...f.bind('quantity')} />
          <TextArea label="Notes" {...f.bind('notes')} />
          {med && <p>Total: <strong>{money(med.unitPrice * qty)}</strong> <span className="muted">({money(med.unitPrice)} × {qty})</span></p>}
          {rxId && <p className="muted">Linked to prescription #{rxId}</p>}
          <FormError msg={err} />
          {ok && <div className="alert" style={{ background: '#dcfce7', color: '#166534' }}>{ok}</div>}
          <button className="btn" disabled={busy || !f.v.patientId || !f.v.medicineId}>{busy ? 'Dispensing…' : 'Dispense'}</button>
        </form>

        <div>
          <h2 style={{ marginBottom: 8 }}>Patient's prescriptions</h2>
          {!f.v.patientId && <p className="muted">Pick a patient to see what their doctors prescribed.</p>}
          {f.v.patientId && prescriptions.length === 0 && <p className="muted">No prescriptions on record.</p>}
          <div className="chips">
            {prescriptions.map((p) => (
              <button type="button" key={p.id} className="chip" style={rxId === p.id ? { borderColor: '#0f766e', background: '#e3f4f1' } : undefined} onClick={() => useRx(p.id, p.medication, p.dosage)}>
                <strong>{p.medication}</strong> {p.dosage && <span>· {p.dosage}</span>}
                <div className="muted">{p.instructions ?? ''} — Dr. {p.doctorName}, {dt(p.createdAt)}</div>
              </button>
            ))}
          </div>
        </div>
      </div>
    </Page>
  );
}
