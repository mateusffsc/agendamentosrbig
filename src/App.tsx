import React from 'react'
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom'
import BookingForm from './components/BookingForm'
import AdminPanel from './components/AdminPanel'

function HomePage() {
  return (
    <main className="min-h-screen bg-gray-50 py-12">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-12">
          <h2 className="text-4xl font-bold text-gray-900 mb-4">
            Agende seu horário com os melhores profissionais
          </h2>
          <p className="text-xl text-gray-600 max-w-2xl mx-auto">
            No Sr Bigode, oferecemos serviços premium de barbearia com agendamento fácil e rápido. 
            Escolha seu barbeiro favorito e garante seu horário.
          </p>
        </div>
        <BookingForm />
      </div>
    </main>
  )
}

function AdminPage() {
  return <AdminPanel />
}

function App() {
  return (
    <Router>
      <div className="min-h-screen bg-gray-50">
        <Routes>
          <Route path="/" element={<HomePage />} />
          <Route path="/admin" element={<AdminPage />} />
        </Routes>
      </div>
    </Router>
  )
}

export default App