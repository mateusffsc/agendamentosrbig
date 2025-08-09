import React, { useState, useEffect } from 'react'
import { supabase, createAppointmentAutomated, getAvailableTimes } from '../lib/supabase'
import type { Barber, Service, CreateAppointmentParams } from '../lib/supabase'
import { formatPhoneNumber, isValidBrazilianPhone } from '../utils/phoneValidation'
import { Calendar, Clock, User, Phone, Mail, MessageSquare, Check, Scissors, Star, ChevronRight } from 'lucide-react'

export default function BookingForm() {
  const [barbers, setBarbers] = useState<Barber[]>([])
  const [services, setServices] = useState<Service[]>([])
  const [availableTimes, setAvailableTimes] = useState<Array<{time_slot: string, available: boolean}>>([])
  const [loading, setLoading] = useState(true)
  const [submitting, setSubmitting] = useState(false)
  const [success, setSuccess] = useState(false)
  const [step, setStep] = useState(1)

  const [formData, setFormData] = useState({
    barber_id: 0,
    service_ids: [] as number[],
    date: '',
    time: '',
    client_name: '',
    client_phone: '',
    client_email: '',
    note: ''
  })

  useEffect(() => {
    fetchData()
  }, [])

  useEffect(() => {
    if (formData.barber_id && formData.date && formData.service_ids.length > 0) {
      fetchAvailableTimes()
    } else {
      setAvailableTimes([])
    }
  }, [formData.barber_id, formData.date, formData.service_ids])

  const fetchData = async () => {
    try {
      const [barbersResponse, servicesResponse] = await Promise.all([
        supabase.from('barbers').select(`
          id, name, phone, email,
          users!inner(username)
        `).order('name'),
        supabase.from('services').select('*').order('name')
      ])

      if (barbersResponse.data) setBarbers(barbersResponse.data)
      if (servicesResponse.data) setServices(servicesResponse.data)
    } catch (error) {
      console.error('Erro ao carregar dados:', error)
    } finally {
      setLoading(false)
    }
  }

  const fetchAvailableTimes = async () => {
    if (!formData.barber_id || !formData.date || formData.service_ids.length === 0) return

    console.log('Buscando horários para:', {
      barber_id: formData.barber_id,
      date: formData.date,
      service_ids: formData.service_ids
    })

    try {
      const times = await getAvailableTimes(formData.barber_id, formData.date, formData.service_ids)
      console.log('Horários retornados:', times)
      setAvailableTimes(times)
    } catch (error) {
      console.error('Erro ao carregar horários disponíveis:', error)
      setAvailableTimes([])
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    
    if (!validateForm()) {
      return
    }
    
    setSubmitting(true)

    try {
      const appointmentDateTime = `${formData.date} ${formData.time}`
      
      const params: CreateAppointmentParams = {
        client_name: formData.client_name,
        client_phone: formData.client_phone,
        client_email: formData.client_email || undefined,
        barber_id: formData.barber_id,
        appointment_datetime: appointmentDateTime,
        service_ids: formData.service_ids,
        note: formData.note || undefined,
        auto_create_client: true
      }

      const result = await createAppointmentAutomated(params)

      if (result.success) {
        setSuccess(true)
        setFormData({
          barber_id: 0,
          service_ids: [],
          date: '',
          time: '',
          client_name: '',
          client_phone: '',
          client_email: '',
          note: ''
        })
        setStep(1)
      } else {
        alert(result.message || 'Erro ao realizar agendamento')
      }
    } catch (error) {
      console.error('Erro ao agendar:', error)
      alert('Erro ao realizar agendamento. Tente novamente.')
    } finally {
      setSubmitting(false)
    }
  }

  const getMinDate = () => {
    const today = new Date()
    return today.toISOString().split('T')[0]
  }

  const getSelectedServices = () => {
    return services.filter(s => formData.service_ids.includes(s.id))
  }

  const getTotalPrice = () => {
    return getSelectedServices().reduce((sum, service) => sum + service.price, 0)
  }

  const getTotalDuration = () => {
    return getSelectedServices().reduce((sum, service) => sum + service.duration_minutes, 0)
  }

  const toggleService = (serviceId: number) => {
    setFormData(prev => ({
      ...prev,
      service_ids: prev.service_ids.includes(serviceId)
        ? prev.service_ids.filter(id => id !== serviceId)
        : [...prev.service_ids, serviceId]
    }))
  }

  const handlePhoneChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const formatted = formatPhoneNumber(e.target.value)
    setFormData({ ...formData, client_phone: formatted })
  }

  const getBarberPhoto = (barberName: string) => {
    const photos: { [key: string]: string } = {
      'admin': 'https://i.ibb.co/YFwtW2vq/image.png',
      'roberto': 'https://i.ibb.co/V0f50tgs/image.png'
    }
    
    // Case-insensitive lookup
    const normalizedName = barberName.toLowerCase()
    
    // Return specific photo if available, otherwise return admin photo as default
    return photos[normalizedName] || photos['admin']
  }

  const validateForm = () => {
    if (!formData.client_name.trim()) {
      alert('Nome é obrigatório')
      return false
    }
    
    if (!formData.client_phone.trim()) {
      alert('Telefone é obrigatório')
      return false
    }
    
    if (!isValidBrazilianPhone(formData.client_phone)) {
      alert('Telefone deve estar no formato (31) 97322-3898')
      return false
    }
    
    return true
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="animate-spin rounded-full h-12 w-12 border-4 border-yellow-600 border-t-transparent"></div>
      </div>
    )
  }

  if (success) {
    return (
      <div className="max-w-md mx-auto bg-white rounded-2xl shadow-xl p-8 text-center">
        <div className="w-20 h-20 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-6">
          <Check className="w-10 h-10 text-green-600" />
        </div>
        <h2 className="text-3xl font-bold text-gray-900 mb-4">Agendamento Confirmado!</h2>
        <p className="text-gray-600 mb-8 leading-relaxed">
          Seu horário foi marcado com sucesso. Entraremos em contato em breve para confirmar todos os detalhes.
        </p>
        <button
          onClick={() => setSuccess(false)}
          className="w-full bg-gradient-to-r from-yellow-600 to-yellow-700 text-white py-4 rounded-xl font-semibold text-lg hover:from-yellow-700 hover:to-yellow-800 transition-all duration-300 transform hover:scale-105"
        >
          Fazer Novo Agendamento
        </button>
      </div>
    )
  }

  return (
    <div className="max-w-4xl mx-auto">
      {/* Progress Steps */}
      <div className="mb-8">
        <div className="flex items-center justify-center space-x-4">
          {[1, 2, 3, 4].map((stepNumber) => (
            <div key={stepNumber} className="flex items-center">
              <div className={`w-10 h-10 rounded-full flex items-center justify-center font-semibold ${
                step >= stepNumber 
                  ? 'bg-yellow-600 text-white' 
                  : 'bg-gray-200 text-gray-500'
              }`}>
                {stepNumber}
              </div>
              {stepNumber < 4 && (
                <ChevronRight className={`w-5 h-5 mx-2 ${
                  step > stepNumber ? 'text-yellow-600' : 'text-gray-300'
                }`} />
              )}
            </div>
          ))}
        </div>
        <div className="flex justify-center mt-4">
          <div className="text-sm text-gray-600 text-center">
            {step === 1 && 'Escolha seu Barbeiro'}
            {step === 2 && 'Selecione os Serviços'}
            {step === 3 && 'Data e Horário'}
            {step === 4 && 'Seus Dados'}
          </div>
        </div>
      </div>

      <div className="bg-white rounded-2xl shadow-xl overflow-hidden">
        <div className="bg-gradient-to-r from-yellow-600 to-yellow-700 px-8 py-6">
          <h1 className="text-3xl font-bold text-white text-center">Agende Seu Horário</h1>
          <p className="text-yellow-100 text-center mt-2">Sr Bigode - Barbearia Premium</p>
        </div>

        <form onSubmit={handleSubmit} className="p-8">
          {/* Step 1: Escolha do Barbeiro */}
          {step === 1 && (
            <div className="space-y-6">
              <h2 className="text-2xl font-bold text-gray-900 mb-6">Escolha seu Barbeiro</h2>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {barbers.map((barber) => (
                  <div
                    key={barber.id}
                    onClick={() => {
                      setFormData({ ...formData, barber_id: barber.id })
                      setStep(2)
                    }}
                    className={`cursor-pointer border-2 rounded-xl p-6 transition-all duration-300 hover:shadow-lg ${
                      formData.barber_id === barber.id
                        ? 'border-yellow-600 bg-yellow-50 shadow-lg'
                        : 'border-gray-200 hover:border-yellow-300'
                    }`}
                  >
                    <div className="text-center">
                      <div className="w-24 h-24 rounded-full mx-auto mb-4 overflow-hidden border-4 border-yellow-400">
                        <img 
                          src={getBarberPhoto(barber.name)} 
                          alt={barber.name}
                          className="w-full h-full object-cover"
                          onError={(e) => {
                            // If image fails to load, show fallback with scissors icon
                            const target = e.currentTarget
                            target.style.display = 'none'
                            const fallback = document.createElement('div')
                            fallback.className = 'w-24 h-24 bg-gradient-to-br from-yellow-400 to-yellow-600 rounded-full mx-auto mb-4 flex items-center justify-center'
                            fallback.innerHTML = '<svg class="w-10 h-10 text-white" fill="currentColor" viewBox="0 0 24 24"><path d="M19 3L13 9l.7.7c1.4.4 3.3 1.8 4.3 3.3l2-2V3h-1zM8.2 5L5 8.2V19h7.8L19 12.8 8.2 5z"/></svg>'
                            target.parentNode?.appendChild(fallback)
                          }}
                        />
                      </div>
                      <h3 className="font-bold text-lg text-gray-900 mb-2">{barber.name}</h3>
                      <div className="flex items-center justify-center mb-2">
                        {[...Array(5)].map((_, i) => (
                          <Star key={i} className="w-4 h-4 text-yellow-400 fill-current" />
                        ))}
                      </div>
                      <p className="text-sm text-gray-600">Especialista Premium</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Step 2: Seleção de Serviços */}
          {step === 2 && (
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <h2 className="text-2xl font-bold text-gray-900">Selecione os Serviços</h2>
                <button
                  type="button"
                  onClick={() => setStep(1)}
                  className="text-yellow-600 hover:text-yellow-700 font-medium"
                >
                  ← Voltar
                </button>
              </div>
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {services.map((service) => (
                  <div
                    key={service.id}
                    onClick={() => toggleService(service.id)}
                    className={`cursor-pointer border-2 rounded-xl p-6 transition-all duration-300 ${
                      formData.service_ids.includes(service.id)
                        ? 'border-yellow-600 bg-yellow-50 shadow-lg'
                        : 'border-gray-200 hover:border-yellow-300 hover:shadow-md'
                    }`}
                  >
                    <div className="flex justify-between items-start mb-3">
                      <h3 className="font-bold text-lg text-gray-900">{service.name}</h3>
                      <div className="text-right">
                        <div className="text-2xl font-bold text-yellow-600">
                          R$ {service.price.toFixed(2)}
                        </div>
                        {service.is_chemical && (
                          <span className="inline-block bg-purple-100 text-purple-800 text-xs px-2 py-1 rounded-full mt-1">
                            Química
                          </span>
                        )}
                      </div>
                    </div>
                    <p className="text-gray-600 mb-3 text-sm leading-relaxed">{service.description}</p>
                    <div className="flex items-center text-sm text-gray-500">
                      <Clock className="w-4 h-4 mr-2" />
                      {service.duration_minutes} minutos
                    </div>
                  </div>
                ))}
              </div>

              {formData.service_ids.length > 0 && (
                <div className="bg-gray-50 rounded-xl p-6">
                  <h3 className="font-semibold text-gray-900 mb-3">Resumo dos Serviços</h3>
                  <div className="space-y-2">
                    {getSelectedServices().map((service) => (
                      <div key={service.id} className="flex justify-between text-sm">
                        <span>{service.name}</span>
                        <span>R$ {service.price.toFixed(2)}</span>
                      </div>
                    ))}
                    <div className="border-t pt-2 mt-2">
                      <div className="flex justify-between font-semibold">
                        <span>Total: {getTotalDuration()} min</span>
                        <span>R$ {getTotalPrice().toFixed(2)}</span>
                      </div>
                    </div>
                  </div>
                </div>
              )}

              <button
                type="button"
                onClick={() => setStep(3)}
                disabled={formData.service_ids.length === 0}
                className="w-full bg-yellow-600 text-white py-4 rounded-xl font-semibold text-lg hover:bg-yellow-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors"
              >
                Continuar
              </button>
            </div>
          )}

          {/* Step 3: Data e Horário */}
          {step === 3 && (
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <h2 className="text-2xl font-bold text-gray-900">Data e Horário</h2>
                <button
                  type="button"
                  onClick={() => setStep(2)}
                  className="text-yellow-600 hover:text-yellow-700 font-medium"
                >
                  ← Voltar
                </button>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-3">
                    <Calendar className="inline w-5 h-5 mr-2" />
                    Escolha a Data
                  </label>
                  <input
                    type="date"
                    min={getMinDate()}
                    value={formData.date}
                    onChange={(e) => setFormData({ ...formData, date: e.target.value, time: '' })}
                    className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-yellow-500 focus:border-transparent text-lg"
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-3">
                    <Clock className="inline w-5 h-5 mr-2" />
                    Horários Disponíveis
                  </label>
                  {formData.date ? (
                    <>
                      {availableTimes.length > 0 ? (
                        <div className="grid grid-cols-2 sm:grid-cols-3 gap-2 max-h-64 overflow-y-auto">
                          {availableTimes
                            .filter(slot => slot.available)
                            .map((slot) => (
                            <button
                              key={slot.time_slot}
                              type="button"
                              onClick={() => setFormData({ ...formData, time: slot.time_slot })}
                              className={`py-3 px-2 text-xs sm:text-sm rounded-lg transition-all ${
                                formData.time === slot.time_slot
                                  ? 'bg-yellow-600 text-white shadow-lg'
                                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                              }`}
                            >
                              <div>{slot.time_slot.slice(0, 5)}</div>
                              <div className="text-xs text-gray-500">
                                {slot.duration_minutes}min
                              </div>
                            </button>
                          ))}
                        </div>
                      ) : (
                        <div className="text-center py-8">
                          <div className="animate-spin rounded-full h-8 w-8 border-2 border-yellow-600 border-t-transparent mx-auto mb-4"></div>
                          <p className="text-gray-500 text-sm">Carregando horários disponíveis...</p>
                        </div>
                      )}
                    </>
                  ) : (
                    <p className="text-gray-500 text-sm">Selecione uma data primeiro</p>
                  )}
                  
                  {formData.date && availableTimes.length > 0 && availableTimes.filter(slot => slot.available).length === 0 && (
                    <p className="text-red-500 text-sm">Nenhum horário disponível para esta data.</p>
                  )}
                </div>
              </div>

              <button
                type="button"
                onClick={() => setStep(4)}
                disabled={!formData.date || !formData.time}
                className="w-full bg-yellow-600 text-white py-4 rounded-xl font-semibold text-lg hover:bg-yellow-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors"
              >
                Continuar
              </button>
            </div>
          )}

          {/* Step 4: Dados do Cliente */}
          {step === 4 && (
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <h2 className="text-2xl font-bold text-gray-900">Seus Dados</h2>
                <button
                  type="button"
                  onClick={() => setStep(3)}
                  className="text-yellow-600 hover:text-yellow-700 font-medium"
                >
                  ← Voltar
                </button>
              </div>

              {/* Resumo do Agendamento */}
              <div className="bg-yellow-50 rounded-xl p-6 border border-yellow-200">
                <h3 className="font-semibold text-gray-900 mb-4">Resumo do Agendamento</h3>
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span>Barbeiro:</span>
                    <span className="font-medium">{barbers.find(b => b.id === formData.barber_id)?.name}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Data:</span>
                    <span className="font-medium">{new Date(formData.date + 'T00:00:00').toLocaleDateString('pt-BR')}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Horário:</span>
                    <span className="font-medium">{formData.time}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Serviços:</span>
                    <span className="font-medium">{getSelectedServices().map(s => s.name).join(', ')}</span>
                  </div>
                  <div className="flex justify-between border-t pt-2 mt-2">
                    <span className="font-semibold">Total:</span>
                    <span className="font-bold text-yellow-600">R$ {getTotalPrice().toFixed(2)}</span>
                  </div>
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    <User className="inline w-4 h-4 mr-1" />
                    Nome Completo *
                  </label>
                  <input
                    type="text"
                    value={formData.client_name}
                    onChange={(e) => setFormData({ ...formData, client_name: e.target.value })}
                    className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-yellow-500 focus:border-transparent"
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    <Phone className="inline w-4 h-4 mr-1" />
                    Telefone *
                  </label>
                  <input
                    type="tel"
                    value={formData.client_phone}
                    onChange={handlePhoneChange}
                    placeholder="(31) 99999-9999"
                    className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-yellow-500 focus:border-transparent"
                    required
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  <Mail className="inline w-4 h-4 mr-1" />
                  Email (opcional)
                </label>
                <input
                  type="email"
                  value={formData.client_email}
                  onChange={(e) => setFormData({ ...formData, client_email: e.target.value })}
                  className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-yellow-500 focus:border-transparent"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  <MessageSquare className="inline w-4 h-4 mr-1" />
                  Observações (opcional)
                </label>
                <textarea
                  value={formData.note}
                  onChange={(e) => setFormData({ ...formData, note: e.target.value })}
                  rows={3}
                  className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-yellow-500 focus:border-transparent"
                  placeholder="Alguma observação especial sobre o atendimento..."
                />
              </div>

              <button
                type="submit"
                disabled={submitting || !formData.client_name || !formData.client_phone}
                className="w-full bg-gradient-to-r from-yellow-600 to-yellow-700 text-white py-4 rounded-xl font-semibold text-lg hover:from-yellow-700 hover:to-yellow-800 disabled:bg-gray-400 disabled:cursor-not-allowed transition-all duration-300 transform hover:scale-105"
              >
                {submitting ? (
                  <div className="flex items-center justify-center">
                    <div className="animate-spin rounded-full h-5 w-5 border-2 border-white border-t-transparent mr-2"></div>
                    Confirmando Agendamento...
                  </div>
                ) : (
                  'Confirmar Agendamento'
                )}
              </button>
            </div>
          )}
        </form>
      </div>
    </div>
  )
}