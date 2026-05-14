-- =============================================================
-- Apple Hub — Setup completo para Neon / PostgreSQL serverless
-- Ejecutar en el SQL Editor de Neon o con psql
-- =============================================================

-- TABLAS -------------------------------------------------------

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'empleado')) DEFAULT 'empleado',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    nuip VARCHAR(30) NOT NULL UNIQUE,
    names VARCHAR(255) NOT NULL,
    lastnames VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    age INTEGER NOT NULL CHECK (age >= 0 AND age <= 150),
    gender CHAR(1) NOT NULL CHECK (gender IN ('M', 'F')),
    address TEXT,
    phone_number VARCHAR(25),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL UNIQUE,
    reference_code VARCHAR(50) NOT NULL UNIQUE,
    category VARCHAR(100) NOT NULL,
    price DECIMAL(12, 2) NOT NULL CHECK (price > 0),
    description TEXT NOT NULL,
    stock_quantity INTEGER NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    delivery_address TEXT NOT NULL,
    total_amount DECIMAL(12,2) NOT NULL CHECK (total_amount > 0),
    status VARCHAR(50) NOT NULL CHECK (status IN ('En Proceso', 'Entregado', 'Cancelado', 'Devuelto')) DEFAULT 'En Proceso',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(12,2) NOT NULL CHECK (unit_price > 0),
    subtotal DECIMAL(13,2) NOT NULL CHECK (subtotal > 0),
    status VARCHAR(50) NOT NULL CHECK (status IN ('Enviado', 'Entregado', 'Cancelado', 'Devuelto', 'Garantía')) DEFAULT 'Enviado',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE warranties (
    id SERIAL PRIMARY KEY,
    order_item_id INTEGER NOT NULL UNIQUE REFERENCES order_items(id) ON DELETE CASCADE,
    warranty_reason TEXT DEFAULT 'Producto defectuoso de fábrica',
    warranty_status VARCHAR(50) NOT NULL CHECK (warranty_status IN ('En Proceso', 'Aprobada', 'Rechazada', 'Completada')) DEFAULT 'Aprobada',
    warranty_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    notes TEXT DEFAULT 'Se evaluó el caso y Apple Inc. autorizó el cambio del producto',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE returns (
    id SERIAL PRIMARY KEY,
    order_item_id INTEGER NOT NULL UNIQUE REFERENCES order_items(id) ON DELETE CASCADE,
    return_reason TEXT,
    return_status VARCHAR(50) NOT NULL CHECK (return_status IN ('Solicitada', 'Aprobada', 'Rechazada', 'Completada')) DEFAULT 'Solicitada',
    return_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completion_date TIMESTAMP WITH TIME ZONE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- FUNCIÓN: total_revenues() ------------------------------------

CREATE OR REPLACE FUNCTION total_revenues()
RETURNS DECIMAL(14, 2)
LANGUAGE plpgsql
AS $$
    DECLARE
        total DECIMAL(14, 2);
    BEGIN
        SELECT COALESCE(SUM(subtotal), 0.00)
        INTO total
        FROM order_items
        WHERE status IN ('Enviado', 'Entregado', 'Garantía');

        RETURN total;
    END;
$$;

-- PROCEDURE: create_order() ------------------------------------

CREATE OR REPLACE PROCEDURE create_order(
    p_customer_id INTEGER,
    p_delivery_address TEXT,
    p_items JSONB
)
LANGUAGE plpgsql
AS $$
    DECLARE
        v_order_id INTEGER;
        v_total DECIMAL(12,2) := 0.00;
        v_item JSONB;
        v_price DECIMAL(12,2);
        v_subtotal DECIMAL(13,2);
    BEGIN
        INSERT INTO orders (customer_id, delivery_address, total_amount)
        VALUES (p_customer_id, p_delivery_address, 0.01)
        RETURNING id INTO v_order_id;

        FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
        LOOP
            SELECT price INTO v_price
            FROM products WHERE id = (v_item->>'product_id')::INTEGER;

            v_subtotal := v_price * (v_item->>'quantity')::INTEGER;

            INSERT INTO order_items (order_id, product_id, quantity, unit_price, subtotal)
            VALUES (v_order_id, (v_item->>'product_id')::INTEGER,
                    (v_item->>'quantity')::INTEGER, v_price, v_subtotal);

            v_total := v_total + v_subtotal;
        END LOOP;

        UPDATE orders
        SET total_amount = v_total, updated_at = CURRENT_TIMESTAMP
        WHERE id = v_order_id;
    END;
$$;

-- TRIGGER: actualizar stock al insertar/actualizar order_items --

CREATE OR REPLACE FUNCTION updating_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
    DECLARE
        actual_stock INT;
    BEGIN
        IF TG_OP = 'INSERT' THEN
            SELECT stock_quantity INTO actual_stock
            FROM products WHERE id = NEW.product_id;

            IF actual_stock >= NEW.quantity THEN
                UPDATE products
                SET stock_quantity = stock_quantity - NEW.quantity
                WHERE id = NEW.product_id;
            ELSE
                RAISE EXCEPTION 'No hay suficiente stock de producto para realizar el pedido.';
            END IF;

            RETURN NEW;

        ELSIF TG_OP = 'UPDATE' THEN
            IF NEW.status IN ('Cancelado', 'Devuelto') AND OLD.status IN ('Enviado', 'Entregado', 'Garantía') THEN
                UPDATE products
                SET stock_quantity = stock_quantity + NEW.quantity
                WHERE id = NEW.product_id;
            ELSEIF NEW.status IN ('Enviado', 'Entregado', 'Garantía') AND OLD.status IN ('Cancelado', 'Devuelto') THEN
                UPDATE products
                SET stock_quantity = stock_quantity - NEW.quantity
                WHERE id = NEW.product_id;
            END IF;

            RETURN NEW;
        END IF;
    END;
$$;

CREATE TRIGGER trigger_updating_stock
AFTER INSERT OR UPDATE ON order_items
FOR EACH ROW
EXECUTE FUNCTION updating_stock();

-- TRIGGER: insertar garantía automáticamente -------------------

CREATE OR REPLACE FUNCTION insert_warranty()
    RETURNS TRIGGER
    LANGUAGE plpgsql
AS $$
    BEGIN
        IF NEW.status = 'Garantía' AND (OLD.status IS NULL OR OLD.status != 'Garantía') THEN
            IF NOT EXISTS (SELECT 1 FROM warranties WHERE order_item_id = NEW.id) THEN
                INSERT INTO warranties (order_item_id)
                VALUES (NEW.id);
            END IF;
        END IF;

        RETURN NEW;
    END;
$$;

CREATE TRIGGER trigger_insert_warranty
AFTER UPDATE ON order_items
FOR EACH ROW
EXECUTE FUNCTION insert_warranty();

-- TRIGGER: insertar devolución automáticamente ----------------

CREATE OR REPLACE FUNCTION insert_return()
    RETURNS TRIGGER
    LANGUAGE plpgsql
AS $$
    BEGIN
        IF NEW.status IN ('Devuelto', 'Cancelado')
            AND (OLD.status IS NULL OR OLD.status NOT IN ('Devuelto', 'Cancelado')) THEN
            IF NOT EXISTS (SELECT 1 FROM returns WHERE order_item_id = NEW.id) THEN
                INSERT INTO returns (order_item_id, return_reason)
                VALUES (NEW.id,
                        CASE
                            WHEN NEW.status = 'Cancelado' THEN 'Cancelación de pedido'
                            WHEN NEW.status = 'Devuelto' THEN 'Producto devuelto'
                        END);
            END IF;
        END IF;

        RETURN NEW;
    END;
$$;

CREATE TRIGGER trigger_insert_return
AFTER UPDATE ON order_items
FOR EACH ROW
EXECUTE FUNCTION insert_return();

-- SEED DATA ----------------------------------------------------
-- Usuarios con contraseñas hasheadas con bcrypt (cost 10)
-- Credenciales: admin → 'admin' | empleado01 → 'empleado01' | empleado02 → 'empleado02'

INSERT INTO users (name, email, password, role)
VALUES
('Camilo Jiménez',    'jmncamilo@gmail.com',        '$2b$10$cqy1Sx8I.IMV0vF1apUMt.bBakXki96ZYyvbUi0bHYs/pV5TZaxRO', 'admin'),
('Felipe Mora',       'correo-prueba01@gmail.com',  '$2b$10$0XOisiDY4FGZ0ze/fd4IPuFphdFDf6qbOjHgKikmbR26GgzeSJ..W', 'empleado'),
('Juan Esteban Aponte','correo-prueba02@gmail.com', '$2b$10$x8Xq9I0mN5igzgyHHA3Dy.vy8VpOXKKekTuUpFH47VMcAWsL9tJna', 'empleado');

INSERT INTO customers (nuip, names, lastnames, email, age, gender, address, phone_number)
VALUES
('1234567890', 'Ana María',     'Rodríguez Silva',   'ana.rodriguez@email.com',    28, 'F', 'Calle 123 #45-67, Bogotá',          '3001234567'),
('9876543210', 'Carlos Andrés', 'Martínez López',    'carlos.martinez@email.com',  35, 'M', 'Carrera 15 #78-90, Medellín',        '3059876543'),
('1122334455', 'Laura Sofía',   'García Hernández',  'laura.garcia@email.com',     42, 'F', 'Avenida 68 #23-45, Cali',            '3021122334'),
('5566778899', 'Miguel Ángel',  'Sánchez Ruiz',      'miguel.sanchez@email.com',   29, 'M', 'Calle 45 #12-34, Barranquilla',      '3035566778'),
('2233445566', 'Valentina',     'Torres Morales',    'valentina.torres@email.com', 31, 'F', 'Carrera 7 #56-78, Bucaramanga',      '3042233445'),
('7788990011', 'Sebastián David','Ramírez Castro',   'sebastian.ramirez@email.com',26, 'M', 'Transversal 12 #89-01, Pereira',     '3057788990');

INSERT INTO products (product_name, reference_code, category, price, description, stock_quantity) VALUES
('MacBook Pro M4',          'AAPL-0001', 'Mac',         9500000.00, 'Chip M4 Pro de 12 núcleos, 18GB de RAM unificada, pantalla Liquid Retina XDR de 14 pulgadas, almacenamiento SSD de 512GB', 15),
('iPhone 16 Pro Max',       'AAPL-0002', 'iPhone',      6800000.00, 'Chip A18 Pro, sistema de cámaras Pro con teleobjetivo 5x, pantalla Super Retina XDR de 6.7 pulgadas, batería de hasta 33 horas de video', 25),
('Apple Watch Ultra 2',     'AAPL-0003', 'Watch',       4200000.00, 'Chip S9 SiP, pantalla Always-On más brillante, resistencia hasta 100m, GPS de doble frecuencia, hasta 72 horas de batería', 12),
('iPad Pro M4 13 Pulgadas', 'AAPL-0004', 'iPad',        8500000.00, 'Chip M4 con CPU de 10 núcleos, pantalla Ultra Retina XDR de 13 pulgadas, soporte para Apple Pencil Pro, conectividad 5G', 8),
('AirPods Pro 3era Gen',    'AAPL-0005', 'AirPods',     1200000.00, 'Chip H2, cancelación activa de ruido hasta 2x mejor, audio espacial personalizado, hasta 6 horas de reproducción', 30),
('Mac Studio M2 Ultra',     'AAPL-0006', 'Mac',        19500000.00, 'Chip M2 Ultra con CPU de 24 núcleos y GPU de 76 núcleos, 64GB de RAM unificada, 4 puertos Thunderbolt 4', 9),
('Apple TV 4K',             'AAPL-0007', 'Apple Home',   950000.00, 'Chip A15 Bionic, soporte HDR10+ y Dolby Vision, audio espacial, Siri Remote con USB-C', 20),
('iMac M3 24 Pulgadas',     'AAPL-0008', 'Mac',         7800000.00, 'Chip M3 con CPU de 8 núcleos, pantalla Retina 4.5K de 24 pulgadas, cámara FaceTime HD 1080p, Magic Keyboard y Magic Mouse incluidos', 10),
('Mac mini M2 Pro',         'AAPL-0009', 'Mac',         6200000.00, 'Chip M2 Pro con CPU de 12 núcleos, 16GB de RAM unificada, 2 puertos Thunderbolt 4, conectividad Wi-Fi 6E', 18),
('Apple Vision Pro',        'AAPL-0010', 'Accesorios', 16500000.00, 'Chip M2 y R1, pantallas micro-OLED 4K, seguimiento ocular y de manos, audio espacial, experiencia de realidad mixta', 7),
('HomePod 2da Gen',         'AAPL-0011', 'Accesorios',  1800000.00, 'Chip S7, audio computacional con cancelación de beamforming, Siri integrado, compatible con Matter', 22);

-- Pedido de muestra (dispara el trigger de stock automáticamente)
CALL create_order(
    1,
    'Calle 100 #15-23, Villavicencio',
    '[{"product_id": 1, "quantity": 1}, {"product_id": 2, "quantity": 1}]'::JSONB
);
