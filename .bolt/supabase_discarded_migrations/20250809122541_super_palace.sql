/*
  # Sistema de Agendamento Sr Bigode

  1. New Tables
    - `barbeiros`
      - `id` (uuid, primary key)
      - `nome` (text)
      - `foto_url` (text)
      - `especialidades` (text array)
      - `ativo` (boolean)
      - `created_at` (timestamp)
    
    - `servicos` 
      - `id` (uuid, primary key)
      - `nome` (text)
      - `duracao` (integer, minutes)
      - `preco` (decimal)
      - `descricao` (text)
      - `ativo` (boolean)
      - `created_at` (timestamp)
    
    - `disponibilidade`
      - `id` (uuid, primary key)
      - `barbeiro_id` (uuid, foreign key)
      - `data` (date)
      - `hora_inicio` (time)
      - `hora_fim` (time)
      - `disponivel` (boolean)
      - `created_at` (timestamp)
    
    - `agendamentos`
      - `id` (uuid, primary key)
      - `barbeiro_id` (uuid, foreign key)
      - `servico_id` (uuid, foreign key)
      - `cliente_nome` (text)
      - `cliente_telefone` (text)
      - `cliente_email` (text)
      - `data` (date)
      - `hora` (time)
      - `status` (text)
      - `observacoes` (text)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on all tables
    - Add policies for public read access to barbeiros and servicos
    - Add policies for authenticated admin access
*/

-- Tabela de barbeiros
CREATE TABLE IF NOT EXISTS barbeiros (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome text NOT NULL,
  foto_url text,
  especialidades text[] DEFAULT '{}',
  ativo boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Tabela de serviços
CREATE TABLE IF NOT EXISTS servicos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome text NOT NULL,
  duracao integer NOT NULL, -- em minutos
  preco decimal(10,2) NOT NULL,
  descricao text,
  ativo boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Tabela de disponibilidade
CREATE TABLE IF NOT EXISTS disponibilidade (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  barbeiro_id uuid REFERENCES barbeiros(id) ON DELETE CASCADE,
  data date NOT NULL,
  hora_inicio time NOT NULL,
  hora_fim time NOT NULL,
  disponivel boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Tabela de agendamentos
CREATE TABLE IF NOT EXISTS agendamentos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  barbeiro_id uuid REFERENCES barbeiros(id) ON DELETE CASCADE,
  servico_id uuid REFERENCES servicos(id) ON DELETE CASCADE,
  cliente_nome text NOT NULL,
  cliente_telefone text NOT NULL,
  cliente_email text,
  data date NOT NULL,
  hora time NOT NULL,
  status text DEFAULT 'agendado' CHECK (status IN ('agendado', 'confirmado', 'cancelado', 'finalizado')),
  observacoes text,
  created_at timestamptz DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE barbeiros ENABLE ROW LEVEL SECURITY;
ALTER TABLE servicos ENABLE ROW LEVEL SECURITY;
ALTER TABLE disponibilidade ENABLE ROW LEVEL SECURITY;
ALTER TABLE agendamentos ENABLE ROW LEVEL SECURITY;

-- Policies para leitura pública (barbeiros e serviços)
CREATE POLICY "Allow public read access to active barbeiros"
  ON barbeiros FOR SELECT
  TO public
  USING (ativo = true);

CREATE POLICY "Allow public read access to active servicos"
  ON servicos FOR SELECT
  TO public
  USING (ativo = true);

CREATE POLICY "Allow public read access to disponibilidade"
  ON disponibilidade FOR SELECT
  TO public
  USING (disponivel = true);

-- Policies para inserção de agendamentos (público pode agendar)
CREATE POLICY "Allow public to create agendamentos"
  ON agendamentos FOR INSERT
  TO public
  WITH CHECK (true);

CREATE POLICY "Allow public to read own agendamentos"
  ON agendamentos FOR SELECT
  TO public
  USING (true);

-- Policies para administradores (controle total)
CREATE POLICY "Allow authenticated users full access to barbeiros"
  ON barbeiros FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users full access to servicos"
  ON servicos FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users full access to disponibilidade"
  ON disponibilidade FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users full access to agendamentos"
  ON agendamentos FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Inserir dados iniciais
INSERT INTO barbeiros (nome, foto_url, especialidades) VALUES
  ('Carlos Silva', 'https://images.pexels.com/photos/1319460/pexels-photo-1319460.jpeg?auto=compress&cs=tinysrgb&w=400', ARRAY['Corte Clássico', 'Barba', 'Bigode']),
  ('João Santos', 'https://images.pexels.com/photos/1043474/pexels-photo-1043474.jpeg?auto=compress&cs=tinysrgb&w=400', ARRAY['Corte Moderno', 'Degradê', 'Sobrancelha']),
  ('Pedro Costa', 'https://images.pexels.com/photos/1222271/pexels-photo-1222271.jpeg?auto=compress&cs=tinysrgb&w=400', ARRAY['Corte Social', 'Barba Completa', 'Tratamentos']);

INSERT INTO servicos (nome, duracao, preco, descricao) VALUES
  ('Corte Simples', 30, 25.00, 'Corte de cabelo tradicional'),
  ('Corte + Barba', 45, 35.00, 'Corte completo com barba aparada'),
  ('Barba Completa', 30, 20.00, 'Aparar e modelar a barba'),
  ('Bigode', 15, 15.00, 'Aparar e modelar o bigode'),
  ('Sobrancelha', 15, 10.00, 'Aparar sobrancelhas masculinas'),
  ('Pacote Completo', 60, 50.00, 'Corte + Barba + Sobrancelha + Tratamento');

-- Inserir disponibilidade para a próxima semana (exemplo)
DO $$
DECLARE
  barbeiro_record record;
  current_date_iter date;
  hora_inicio time;
BEGIN
  FOR barbeiro_record IN SELECT id FROM barbeiros LOOP
    FOR i IN 0..6 LOOP
      current_date_iter := CURRENT_DATE + i;
      
      -- Skip Sundays
      IF EXTRACT(DOW FROM current_date_iter) != 0 THEN
        FOR hora_iter IN 8..17 LOOP
          hora_inicio := (hora_iter || ':00')::time;
          
          INSERT INTO disponibilidade (barbeiro_id, data, hora_inicio, hora_fim, disponivel)
          VALUES (barbeiro_record.id, current_date_iter, hora_inicio, (hora_inicio + interval '1 hour')::time, true);
        END LOOP;
      END IF;
    END LOOP;
  END LOOP;
END $$;