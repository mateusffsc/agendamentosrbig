import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL!
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY!

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

// Tipos baseados no banco de dados atual
export interface Barber {
  id: number
  user_id: number
  name: string
  phone?: string
  email?: string
  commission_rate_service: number
  commission_rate_product: number
  commission_rate_chemical_service: number
  created_at?: string
  updated_at?: string
}

export interface Service {
  id: number
  name: string
  description?: string
  price: number
  duration_minutes: number
  is_chemical: boolean
  created_at?: string
  updated_at?: string
}

export interface Client {
  id: number
  name: string
  phone?: string
  email?: string
  created_at?: string
  updated_at?: string
}

export interface Appointment {
  id: number
  client_id: number
  barber_id: number
  appointment_date: string
  appointment_time: string
  appointment_datetime: string
  services_ids: number[]
  services_names: string
  barber_name: string
  client_name: string
  client_phone: string
  status: 'scheduled' | 'confirmed' | 'completed' | 'cancelled' | 'no_show'
  total_price: number
  note?: string
  payment_method?: 'money' | 'pix' | 'credit_card' | 'debit_card'
  created_at?: string
  updated_at?: string
}

export interface AppointmentService {
  appointment_id: number
  service_id: number
  price_at_booking: number
  commission_rate_applied: number
}

// Função para criar agendamento automatizado
export interface CreateAppointmentParams {
  client_name: string
  client_phone: string
  client_email?: string
  barber_id: number
  appointment_datetime: string
  service_ids: number[]
  note?: string
  auto_create_client?: boolean
}

export interface CreateAppointmentResponse {
  success: boolean
  appointment_id?: number
  client_id?: number
  total_price?: number
  duration_minutes?: number
  message: string
}

// Função para buscar agendamentos
export interface SearchAppointmentsParams {
  start_date?: string
  end_date?: string
  client_name?: string
  client_phone?: string
  barber_name?: string
  service_name?: string
  status?: string
  limit?: number
}

// Funções auxiliares para o Supabase
export const createAppointmentAutomated = async (params: CreateAppointmentParams): Promise<CreateAppointmentResponse> => {
  const { data, error } = await supabase.rpc('create_appointment_automated', {
    p_client_name: params.client_name,
    p_client_phone: params.client_phone,
    p_client_email: params.client_email,
    p_barber_id: params.barber_id,
    p_appointment_datetime: params.appointment_datetime,
    p_service_ids: params.service_ids,
    p_note: params.note,
    p_auto_create_client: params.auto_create_client ?? true
  })
  
  if (error) {
    console.error('Erro ao criar agendamento:', error)
    return { success: false, message: error.message }
  }
  
  return data
}

export const searchAppointments = async (params: SearchAppointmentsParams = {}) => {
  const { data, error } = await supabase.rpc('search_appointments', {
    p_start_date: params.start_date,
    p_end_date: params.end_date,
    p_client_name: params.client_name,
    p_client_phone: params.client_phone,
    p_barber_name: params.barber_name,
    p_service_name: params.service_name,
    p_status: params.status,
    p_limit: params.limit ?? 100
  })
  
  if (error) {
    console.error('Erro ao buscar agendamentos:', error)
    return []
  }
  
  return data || []
}

export const getBarberSchedule = async (barberId: number, date: string) => {
  const { data, error } = await supabase.rpc('get_barber_schedule', {
    p_barber_id: barberId,
    p_date: date
  })
  
  if (error) {
    console.error('Erro ao buscar agenda do barbeiro:', error)
    return []
  }
  
  return data || []
}

export const getAvailableTimes = async (barberId: number, date: string, serviceIds: number[] = []) => {
  console.log('Chamando getAvailableTimes com:', { barberId, date, serviceIds })
  
  const { data, error } = await supabase.rpc('get_available_times', {
    p_barber_id: barberId,
    p_date: date,
    p_service_ids: serviceIds
  })
  
  if (error) {
    console.error('Erro ao buscar horários disponíveis:', error)
    console.error('Detalhes do erro:', error.message, error.details)
    return []
  }
  
  console.log('Dados retornados do Supabase:', data)
  return data || []
}