import { useEffect, useState, type FormEvent } from 'react';
import { useAppDispatch, useAppSelector } from '../app/hooks';
import { admitPatient, dischargePatient, fetchAdmissions, fetchBeds } from '../features/hospitalSlice';
import { fetchDoctors, fetchPatients } from '../features/usersSlice';
import { Badge, Field, FormActions, FormError, Modal, Page, Select, Table, TextArea, dt, useForm, useSubmit } from '../components/ui';
import type { Admission } from '../types';

function AdmitForm({ onClose, onSaved }: { onClose: () => void; onSaved: () => void }) {
  const dispatch = useAppDispatch();
  const { patients, doctors } = useAppSelector((s) => s.users);
  const beds = useAppSelector((s) => s.hospital.beds);
  const { busy, err, run } = useSubmit();
  const f = useForm({ patientId: '', bedId: '', doctorId: '', reason: '', expected: '' });

  useEffect(() => { dispatch(fetchPatients()); dispatch(fetchDoctors(undefined)); dispatch(fetchBeds('Available')); }, [dispatch]);

  const submit = (e: FormEvent) => {
    e.preventDefault();
    const v = f.v;
    run(() => dispatch(admitPatient({
      patientId: Number(v.patientId), bedId: Number(v.bedId), admittingDoctorId: Number(v.doctorId),
      reasonForAdmission: v.reason, expectedDischargeDate: v.expected || undefined,
    })).unwrap(), () => { onSaved(); onClose(); });
  };

  return (
    <Modal title="Admit patient" onClose={onClose}>
      <form onSubmit={submit}>
        <Select label="Patient" required options={patients.map((p) => ({ value: p.id, label: `${p.fullName} (${p.phone ?? p.email})` }))} {...f.bind('patientId')} />
        <Select label="Admitting doctor" required options={doctors.map((d) => ({ value: d.id, label: `${d.fullName} — ${d.specialization}` }))} {...f.bind('doctorId')} />
        <Select label="Available bed" required options={beds.map((b) => ({ value: b.id, label: `${b.wardName} · ${b.bedNumber}` }))} {...f.bind('bedId')} />
        <Field label="Reason for admission" required {...f.bind('reason')} />
        <Field label="Expected discharge" type="date" {...f.bind('expected')} />
        <FormError msg={err} /><FormActions busy={busy} onCancel={onClose} label="Admit" />
      </form>
    </Modal>
  );
}

function DischargeForm({ adm, onClose, onSaved }: { adm: Admission; onClose: () => void; onSaved: () => void }) {
  const dispatch = useAppDispatch();
  const { busy, err, run } = useSubmit();
  const f = useForm({ summary: '' });
  return (
    <Modal title={`Discharge ${adm.patientName}`} onClose={onClose}>
      <form onSubmit={(e) => { e.preventDefault(); run(() => dispatch(dischargePatient({ id: adm.id, dischargeSummary: f.v.summary || undefined })).unwrap(), () => { onSaved(); onClose(); }); }}>
        <TextArea label="Discharge summary" {...f.bind('summary')} />
        <FormError msg={err} /><FormActions busy={busy} onCancel={onClose} label="Discharge" />
      </form>
    </Modal>
  );
}

export default function Admissions() {
  const dispatch = useAppDispatch();
  const { admissions, loading } = useAppSelector((s) => s.hospital);
  const [admit, setAdmit] = useState(false);
  const [discharging, setDischarging] = useState<Admission | null>(null);
  const load = () => { dispatch(fetchAdmissions()); };
  useEffect(load, [dispatch]);

  return (
    <Page title="Admissions (currently admitted)" actions={<button className="btn" onClick={() => setAdmit(true)}>+ Admit patient</button>}>
      <Table loading={loading} rows={admissions} cols={[
        { header: 'Patient', cell: (a) => a.patientName },
        { header: 'Doctor', cell: (a) => a.doctorName },
        { header: 'Ward / Bed', cell: (a) => `${a.wardName} · ${a.bedNumber}` },
        { header: 'Admitted', cell: (a) => dt(a.admissionDate) },
        { header: 'Reason', cell: (a) => a.reasonForAdmission },
        { header: 'Status', cell: (a) => <Badge text={a.status} /> },
        { header: '', cell: (a) => <button className="btn ghost sm" onClick={() => setDischarging(a)}>Discharge</button> },
      ]} />
      {admit && <AdmitForm onClose={() => setAdmit(false)} onSaved={load} />}
      {discharging && <DischargeForm adm={discharging} onClose={() => setDischarging(null)} onSaved={load} />}
    </Page>
  );
}
