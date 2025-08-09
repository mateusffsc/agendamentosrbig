import React from 'react'
import { Scissors, Phone, MapPin, Clock } from 'lucide-react'

export default function Header() {
  return (
    <header className="bg-gradient-to-r from-black to-gray-900 text-white">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between py-6">
          <div className="flex items-center">
            <Scissors className="w-8 h-8 text-yellow-400 mr-3" />
            <div>
              <h1 className="text-2xl font-bold">Sr Bigode</h1>
              <p className="text-gray-300 text-sm">Barbearia Premium</p>
            </div>
          </div>
          
          <div className="hidden md:flex items-center space-x-6 text-sm">
            <div className="flex items-center">
              <Phone className="w-4 h-4 mr-2 text-yellow-400" />
              <span>(11) 99999-9999</span>
            </div>
            <div className="flex items-center">
              <MapPin className="w-4 h-4 mr-2 text-yellow-400" />
              <span>São Paulo, SP</span>
            </div>
            <div className="flex items-center">
              <Clock className="w-4 h-4 mr-2 text-yellow-400" />
              <span>Seg-Sáb: 8h-21h</span>
            </div>
          </div>
        </div>
        
        <div className="border-t border-gray-700 py-4">
          <div className="flex justify-center">
            <nav className="flex space-x-8">
              <button className="text-yellow-400 font-medium">Agendamento</button>
              <button 
                onClick={() => window.open('/admin', '_blank')}
                className="text-gray-300 hover:text-white transition-colors"
              >
                Admin
              </button>
            </nav>
          </div>
        </div>
      </div>
    </header>
  )
}