import React, { useState, useEffect } from 'react'
import { supabase, searchAppointments, getBarberSchedule } from '../lib/supabase'
import type { Appointment, Barber, Service } from '../lib/supabase'
import { 
  Calendar, Clock, Users, Settings, Plus, Trash2, Edit, CheckCircle, XCircle, 
  Search, Filter, Download, Eye, Phone, Mail, DollarSign, TrendingUp,
  BarChart3, Activity, AlertCircle
} from 'lucide-react'

interface DashboardStats {
  appointments_today: number
  scheduled_today: number
  completed_today: number
  revenue_today: number
  appointments_month: number
  revenue_month: number
  total_clients: number
  active_barbers: number
}

export default function AdminPanel() {
  const [activeTab, setActiveTab] = useState<'dashboard' | 'appointments' | 'schedule' | 'barbers' | 'services'>('dashboard')
  const [appointments, setAppointments] = useState<Appointment[]>([])
  const [barbers, setBarbers] = useState<Barber[]>([])
  const [services, setServices] = useState<Service[]>([])
  const [stats, setStats] = useState<DashboardStats | null>(null)
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState('')
  const [statusFilter, setStatusFilter] = useState('')
  const [dateFilter, setDateFilter] = useState('')
  const [selectedBarber, setSelectedBarber] = useState<number>(0)
  const [scheduleDate, setScheduleDate] = useState(new Date().toISOString().split('T')[0])

  useEffect(() => {
    fetchData()
  }, [activeTab])

  const fetchData = async () => {
    setLoading(true)
    try {
      if (activeTab === 'dashboard') {
        // Buscar estatísticas
        const { data: statsData } = await supabase.from('v_dashboard_stats').select('*').single()
        setStats(statsData)

        // Buscar agendamentos recentes
        const recentAppointments = await searchAppointments({
          start_date: new Date().toISOString().split('T')[0],
          limit: 10
        })
        setAppointments(recentAppointments)
      } else if (activeTab === 'appointments') {
        let params: any = { limit: 100 }
        
        if (searchTerm) {
          if (searchTerm.includes('@')) {
            // Busca por email não implementada diretamente, usar nome
          } else if (searchTerm.match(/\d/)) {
            params.client_phone = searchTerm
          } else {
            params.client_name = searchTerm
          }
        }
        
        if (statusFilter) params.status = statusFilter
        if (dateFilter) {
          params.start_date = dateFilter
          params.end_date = dateFilter
        }

        const appointmentsData = await searchAppointments(params)
        setAppointments(appointmentsData)
      } else if (activeTab === 'barbers') {
        const { data } = await supabase
          .from('barbers')
          .select(`
            *,
            users!inner(username)
          `)
          .order('name')

        setBarbers(data || [])
      } else if (activeTab === 'services') {
        const { data } = await supabase
          .from('services')
          .select('*')
          .order('name')

        setServices(data || [])
      }
    } catch (error) {
      console.error('Erro ao carregar dados:', error)
    } finally {
      setLoading(false)
    }
  }

  const updateAppointmentStatus = async (id: number, status: string) => {
    try {
      const { error } = await supabase
        .from('appointments')
        .update({ status })
        .eq('id', id)

      if (error) throw error
      fetchData()
    } catch (error) {
      console.error('Erro ao atualizar status:', error)
    }
  }

  const formatDate = (dateString: string) => {
    return new Date(dateString + 'T00:00:00').toLocaleDateString('pt-BR')
  }

  const formatCurrency = (value: number) => {
    return new Intl.NumberFormat('pt-BR', {
      style: 'currency',
      currency: 'BRL'
    }).format(value)
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'scheduled': return 'bg-yellow-100 text-yellow-800 border-yellow-200'
      case 'confirmed': return 'bg-blue-100 text-blue-800 border-blue-200'
      case 'completed': return 'bg-green-100 text-green-800 border-green-200'
      case 'cancelled': return 'bg-red-100 text-red-800 border-red-200'
      case 'no_show': return 'bg-gray-100 text-gray-800 border-gray-200'
      default: return 'bg-gray-100 text-gray-800 border-gray-200'
    }
  }

  const getStatusText = (status: string) => {
    switch (status) {
      case 'scheduled': return 'Agendado'
      case 'confirmed': return 'Confirmado'
      case 'completed': return 'Concluído'
      case 'cancelled': return 'Cancelado'
      case 'no_show': return 'Não Compareceu'
      default: return status
    }
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

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <div className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-6">
            <div>
              <h1 className="text-3xl font-bold text-gray-900">Painel Administrativo</h1>
              <p className="text-gray-600">Sr Bigode - Gestão de Agendamentos</p>
            </div>
            <div className="flex items-center space-x-4">
              <button className="bg-yellow-600 text-white px-4 py-2 rounded-lg hover:bg-yellow-700 flex items-center">
                <Download className="w-4 h-4 mr-2" />
                Exportar
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Navigation Tabs */}
      <div className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <nav className="flex space-x-8">
            {[
              { id: 'dashboard', label: 'Dashboard', icon: BarChart3 },
              { id: 'appointments', label: 'Agendamentos', icon: Calendar },
              { id: 'schedule', label: 'Agenda', icon: Clock },
              { id: 'barbers', label: 'Barbeiros', icon: Users },
              { id: 'services', label: 'Serviços', icon: Settings }
            ].map((tab) => {
              const Icon = tab.icon
              return (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id as any)}
                  className={`py-4 px-1 border-b-2 font-medium text-sm flex items-center ${
                    activeTab === tab.id
                      ? 'border-yellow-500 text-yellow-600'
                      : 'border-transparent text-gray-500 hover:text-gray-700'
                  }`}
                >
                  <Icon className="w-4 h-4 mr-2" />
                  {tab.label}
                </button>
              )
            })}
          </nav>
        </div>
      </div>

      {/* Content */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {loading ? (
          <div className="flex items-center justify-center py-12">
            <div className="animate-spin rounded-full h-12 w-12 border-4 border-yellow-600 border-t-transparent"></div>
          </div>
        ) : (
          <>
            {/* Dashboard */}
            {activeTab === 'dashboard' && stats && (
              <div className="space-y-8">
                {/* Stats Cards */}
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                  <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-200">
                    <div className="flex items-center">
                      <div className="p-2 bg-blue-100 rounded-lg">
                        <Calendar className="w-6 h-6 text-blue-600" />
                      </div>
                      <div className="ml-4">
                        <p className="text-sm font-medium text-gray-600">Hoje</p>
                        <p className="text-2xl font-bold text-gray-900">{stats.appointments_today}</p>
                      </div>
                    </div>
                  </div>

                  <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-200">
                    <div className="flex items-center">
                      <div className="p-2 bg-green-100 rounded-lg">
                        <DollarSign className="w-6 h-6 text-green-600" />
                      </div>
                      <div className="ml-4">
                        <p className="text-sm font-medium text-gray-600">Receita Hoje</p>
                        <p className="text-2xl font-bold text-gray-900">{formatCurrency(stats.revenue_today)}</p>
                      </div>
                    </div>
                  </div>

                  <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-200">
                    <div className="flex items-center">
                      <div className="p-2 bg-yellow-100 rounded-lg">
                        <TrendingUp className="w-6 h-6 text-yellow-600" />
                      </div>
                      <div className="ml-4">
                        <p className="text-sm font-medium text-gray-600">Este Mês</p>
                        <p className="text-2xl font-bold text-gray-900">{stats.appointments_month}</p>
                      </div>
                    </div>
                  </div>

                  <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-200">
                    <div className="flex items-center">
                      <div className="p-2 bg-purple-100 rounded-lg">
                        <Users className="w-6 h-6 text-purple-600" />
                      </div>
                      <div className="ml-4">
                        <p className="text-sm font-medium text-gray-600">Clientes</p>
                        <p className="text-2xl font-bold text-gray-900">{stats.total_clients}</p>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Recent Appointments */}
                <div className="bg-white rounded-xl shadow-sm border border-gray-200">
                  <div className="px-6 py-4 border-b border-gray-200">
                    <h2 className="text-lg font-semibold text-gray-900">Agendamentos de Hoje</h2>
                  </div>
                  <div className="overflow-x-auto">
                    <table className="min-w-full divide-y divide-gray-200">
                      <thead className="bg-gray-50">
                        <tr>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Cliente</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Barbeiro</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Horário</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Serviços</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Valor</th>
                        </tr>
                      </thead>
                      <tbody className="bg-white divide-y divide-gray-200">
                        {appointments.slice(0, 10).map((appointment) => (
                          <tr key={appointment.id} className="hover:bg-gray-50">
                            <td className="px-6 py-4 whitespace-nowrap">
                              <div>
                                <div className="text-sm font-medium text-gray-900">{appointment.client_name}</div>
                                <div className="text-sm text-gray-500">{appointment.client_phone}</div>
                              </div>
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                              {appointment.barber_name}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                              {appointment.appointment_time?.slice(0, 5)}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                              {appointment.services_names}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap">
                              <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full border ${getStatusColor(appointment.status)}`}>
                                {getStatusText(appointment.status)}
                              </span>
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                              {formatCurrency(appointment.total_price)}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            )}

            {/* Appointments */}
            {activeTab === 'appointments' && (
              <div className="space-y-6">
                {/* Filters */}
                <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-200">
                  <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">Buscar</label>
                      <div className="relative">
                        <Search className="absolute left-3 top-3 w-4 h-4 text-gray-400" />
                        <input
                          type="text"
                          placeholder="Nome ou telefone..."
                          value={searchTerm}
                          onChange={(e) => setSearchTerm(e.target.value)}
                          className="pl-10 w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-transparent"
                        />
                      </div>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">Status</label>
                      <select
                        value={statusFilter}
                        onChange={(e) => setStatusFilter(e.target.value)}
                        className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-transparent"
                      >
                        <option value="">Todos</option>
                        <option value="scheduled">Agendado</option>
                        <option value="confirmed">Confirmado</option>
                        <option value="completed">Concluído</option>
                        <option value="cancelled">Cancelado</option>
                        <option value="no_show">Não Compareceu</option>
                      </select>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">Data</label>
                      <input
                        type="date"
                        value={dateFilter}
                        onChange={(e) => setDateFilter(e.target.value)}
                        className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-transparent"
                      />
                    </div>
                    <div className="flex items-end">
                      <button
                        onClick={fetchData}
                        className="w-full bg-yellow-600 text-white px-4 py-2 rounded-lg hover:bg-yellow-700 flex items-center justify-center"
                      >
                        <Filter className="w-4 h-4 mr-2" />
                        Filtrar
                      </button>
                    </div>
                  </div>
                </div>

                {/* Appointments Table */}
                <div className="bg-white rounded-xl shadow-sm border border-gray-200">
                  <div className="px-6 py-4 border-b border-gray-200">
                    <h2 className="text-lg font-semibold text-gray-900">
                      Agendamentos ({appointments.length})
                    </h2>
                  </div>
                  <div className="overflow-x-auto">
                    <table className="min-w-full divide-y divide-gray-200">
                      <thead className="bg-gray-50">
                        <tr>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Cliente</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Barbeiro</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Data/Hora</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Serviços</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Valor</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Ações</th>
                        </tr>
                      </thead>
                      <tbody className="bg-white divide-y divide-gray-200">
                        {appointments.map((appointment) => (
                          <tr key={appointment.id} className="hover:bg-gray-50">
                            <td className="px-6 py-4 whitespace-nowrap">
                              <div>
                                <div className="text-sm font-medium text-gray-900">{appointment.client_name}</div>
                                <div className="text-sm text-gray-500 flex items-center">
                                  <Phone className="w-3 h-3 mr-1" />
                                  {appointment.client_phone}
                                </div>
                              </div>
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                              {appointment.barber_name}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                              <div>{formatDate(appointment.appointment_date)}</div>
                              <div className="text-gray-500">{appointment.appointment_time?.slice(0, 5)}</div>
                            </td>
                            <td className="px-6 py-4 text-sm text-gray-900 max-w-xs">
                              <div className="truncate" title={appointment.services_names}>
                                {appointment.services_names}
                              </div>
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap">
                              <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full border ${getStatusColor(appointment.status)}`}>
                                {getStatusText(appointment.status)}
                              </span>
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                              {formatCurrency(appointment.total_price)}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm font-medium space-x-2">
                              {appointment.status === 'scheduled' && (
                                <button
                                  onClick={() => updateAppointmentStatus(appointment.id, 'confirmed')}
                                  className="text-green-600 hover:text-green-900"
                                  title="Confirmar"
                                >
                                  <CheckCircle className="w-4 h-4" />
                                </button>
                              )}
                              {appointment.status === 'confirmed' && (
                                <button
                                  onClick={() => updateAppointmentStatus(appointment.id, 'completed')}
                                  className="text-blue-600 hover:text-blue-900"
                                  title="Finalizar"
                                >
                                  <CheckCircle className="w-4 h-4" />
                                </button>
                              )}
                              <button
                                onClick={() => updateAppointmentStatus(appointment.id, 'cancelled')}
                                className="text-red-600 hover:text-red-900"
                                title="Cancelar"
                              >
                                <XCircle className="w-4 h-4" />
                              </button>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            )}

            {/* Other tabs content would go here */}
            {activeTab === 'schedule' && (
              <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-200">
                <h2 className="text-lg font-semibold text-gray-900 mb-4">Agenda dos Barbeiros</h2>
                <p className="text-gray-600">Funcionalidade em desenvolvimento...</p>
              </div>
            )}

            {activeTab === 'barbers' && (
              <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-200">
                <h2 className="text-lg font-semibold text-gray-900 mb-4">Gerenciar Barbeiros</h2>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                  {barbers.map((barber) => (
                    <div key={barber.id} className="border border-gray-200 rounded-lg p-4">
                      <div className="flex items-center mb-3">
                        <div className="w-12 h-12 rounded-full overflow-hidden border-2 border-yellow-400 mr-3">
                          <img 
                            src={getBarberPhoto(barber.name)} 
                            alt={barber.name}
                            className="w-full h-full object-cover"
                            onError={(e) => {
                              // If image fails to load, show fallback with users icon
                              const target = e.currentTarget
                              target.style.display = 'none'
                              const fallback = document.createElement('div')
                              fallback.className = 'w-12 h-12 bg-gradient-to-br from-yellow-400 to-yellow-600 rounded-full flex items-center justify-center mr-3'
                              fallback.innerHTML = '<svg class="w-6 h-6 text-white" fill="currentColor" viewBox="0 0 24 24"><path d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/></svg>'
                              target.parentNode?.appendChild(fallback)
                            }}
                          />
                        </div>
                        <div>
                          <h3 className="font-medium text-gray-900">{barber.name}</h3>
                          <p className="text-sm text-gray-500">{barber.phone}</p>
                        </div>
                      </div>
                      <div className="text-sm text-gray-600 space-y-1">
                        <p>Comissão Serviços: {(barber.commission_rate_service * 100).toFixed(0)}%</p>
                        <p>Comissão Produtos: {(barber.commission_rate_product * 100).toFixed(0)}%</p>
                        <p>Comissão Química: {(barber.commission_rate_chemical_service * 100).toFixed(0)}%</p>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {activeTab === 'services' && (
              <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-200">
                <h2 className="text-lg font-semibold text-gray-900 mb-4">Gerenciar Serviços</h2>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  {services.map((service) => (
                    <div key={service.id} className="border border-gray-200 rounded-lg p-4">
                      <div className="flex justify-between items-start mb-2">
                        <h3 className="font-medium text-gray-900">{service.name}</h3>
                        <div className="text-right">
                          <div className="text-lg font-bold text-yellow-600">
                            {formatCurrency(service.price)}
                          </div>
                          {service.is_chemical && (
                            <span className="inline-block bg-purple-100 text-purple-800 text-xs px-2 py-1 rounded-full">
                              Química
                            </span>
                          )}
                        </div>
                      </div>
                      <p className="text-sm text-gray-600 mb-2">{service.description}</p>
                      <div className="flex items-center text-sm text-gray-500">
                        <Clock className="w-4 h-4 mr-1" />
                        {service.duration_minutes} minutos
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  )
}