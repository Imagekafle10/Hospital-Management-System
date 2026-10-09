export type Role = 'Admin' | 'Doctor' | 'Patient' | 'Pharmacist';

export interface AuthUser { token: string; userId: number; fullName: string; role: Role; expiresAt: string }

export interface Patient {
  id: number; userId: number; dateOfBirth?: string | null; gender?: string | null; bloodGroup?: string | null;
  address?: string | null; emergencyContact?: string | null; fullName?: string; email?: string; phone?: string | null;
}
export interface Doctor {
  id: number; userId: number; specialization: string; licenseNumber: string; consultationFee: number;
  yearsOfExperience: number; availableFrom?: string | null; availableTo?: string | null;
  photoFileName?: string | null; fullName?: string; email?: string; phone?: string | null;
}
export interface StaffUser { id: number; fullName: string; email: string; role: Role; phone?: string | null; isActive: boolean; createdAt: string }

export interface Appointment {
  id: number; patientId: number; doctorId: number; appointmentDate: string; reason?: string | null;
  status: string; notes?: string | null; patientName?: string; doctorName?: string; doctorSpecialization?: string;
}
export interface Ward { id: number; name: string; wardType: string; floorNumber?: number | null; description?: string | null; totalBeds: number; availableBeds: number }
export interface Bed { id: number; wardId: number; bedNumber: string; status: string; wardName?: string; wardType?: string }
export interface Admission {
  id: number; patientId: number; admittingDoctorId: number; bedId: number; admissionDate: string; dischargeDate?: string | null;
  reasonForAdmission: string; status: string; patientName?: string; doctorName?: string; bedNumber?: string; wardName?: string;
}
export interface Payment {
  id: number; appointmentId: number; patientId: number; amount: number; method: string; status: string;
  createdAt: string; paidAt?: string | null; patientName?: string; doctorName?: string;
}

export interface Medicine {
  id: number; name: string; genericName?: string | null; category?: string | null; manufacturer?: string | null;
  batchNumber?: string | null; unit: string; unitPrice: number; stockQuantity: number; reorderLevel: number;
  expiryDate?: string | null; isActive: boolean; isLowStock: boolean; isExpired: boolean;
}
export interface Dispense {
  id: number; prescriptionId?: number | null; patientId: number; patientName?: string; medicineId: number; medicineName?: string;
  quantity: number; unitPrice: number; totalPrice: number; notes?: string | null; createdAt: string;
}
export interface PatientPrescription { id: number; appointmentId: number; medication: string; dosage?: string | null; instructions?: string | null; createdAt: string; doctorName: string }

export type Stats = Record<
  'patients' | 'doctors' | 'pharmacists' | 'appointments' | 'pendingAppointments' | 'activeAdmissions' |
  'totalBeds' | 'availableBeds' | 'lowStockMedicines' | 'revenue' | 'pharmacySales', number>;
