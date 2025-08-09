import React from 'react'
import { Scissors, Instagram, Facebook, Phone, MapPin } from 'lucide-react'

export default function Footer() {
  return (
    <footer className="bg-black text-white py-12">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
          <div>
            <div className="flex items-center mb-4">
              <Scissors className="w-6 h-6 text-yellow-400 mr-2" />
              <h3 className="text-xl font-bold">Sr Bigode</h3>
            </div>
            <p className="text-gray-400 mb-4">
              A barbearia que combina tradição e modernidade para oferecer o melhor serviço aos nossos clientes.
            </p>
            <div className="flex space-x-4">
              <Instagram className="w-5 h-5 text-gray-400 hover:text-yellow-400 cursor-pointer transition-colors" />
              <Facebook className="w-5 h-5 text-gray-400 hover:text-yellow-400 cursor-pointer transition-colors" />
            </div>
          </div>
          
          <div>
            <h4 className="text-lg font-semibold mb-4 text-yellow-400">Contato</h4>
            <div className="space-y-2 text-gray-400">
              <div className="flex items-center">
                <Phone className="w-4 h-4 mr-2" />
                <span>(11) 99999-9999</span>
              </div>
              <div className="flex items-center">
                <MapPin className="w-4 h-4 mr-2" />
                <span>Rua da Barbearia, 123 - São Paulo, SP</span>
              </div>
            </div>
          </div>
          
          <div>
            <h4 className="text-lg font-semibold mb-4 text-yellow-400">Horários</h4>
            <div className="text-gray-400 space-y-1">
              <p>Segunda a Sábado: 8h - 21h</p>
              <p>Domingo: Fechado</p>
            </div>
          </div>
        </div>
        
        <div className="border-t border-gray-800 pt-8 mt-8 text-center text-gray-400">
          <p>&copy; 2024 Sr Bigode. Todos os direitos reservados.</p>
        </div>
      </div>
    </footer>
  )
}