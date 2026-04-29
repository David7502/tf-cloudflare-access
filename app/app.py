#!/usr/bin/env python3
"""
HR Employee Directory - Flask Application
Intégration Cloudflare Access avec lecture des headers JWT
"""

from flask import Flask, render_template, request, jsonify, g
import sqlite3
import os
from datetime import datetime

app = Flask(__name__)

# Configuration
DB_PATH = '/opt/hr-directory/hr_directory.db'
APP_VERSION = "1.0.0"


def get_db_connection():
    """Crée une connexion à la base de données SQLite"""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    """Initialise la base de données avec des données de démo"""
    # Créer le répertoire si nécessaire
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Création de la table employees
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS employees (
            id INTEGER PRIMARY KEY,
            first_name TEXT NOT NULL,
            last_name TEXT NOT NULL,
            email TEXT NOT NULL,
            department TEXT NOT NULL,
            role TEXT NOT NULL,
            manager TEXT,
            hire_date TEXT,
            location TEXT
        )
    ''')
    
    # Données de démo - Employés internationaux
    employees = [
        (1, 'Alice', 'Martin', 'alice.martin@company.com', 'Engineering', 
         'Senior Developer', 'Bob Chen', '2020-03-15', 'Paris'),
        (2, 'Bob', 'Chen', 'bob.chen@company.com', 'Engineering', 
         'Engineering Manager', 'Carol White', '2018-07-01', 'Singapore'),
        (3, 'Carol', 'White', 'carol.white@company.com', 'Executive', 
         'CTO', None, '2015-01-10', 'New York'),
        (4, 'David', 'Kumar', 'david.kumar@company.com', 'Engineering', 
         'DevOps Engineer', 'Bob Chen', '2021-06-20', 'Bangalore'),
        (5, 'Elena', 'Rodriguez', 'elena.rodriguez@company.com', 'HR', 
         'HR Director', 'Carol White', '2019-04-12', 'Madrid'),
        (6, 'Frank', 'Müller', 'frank.muller@company.com', 'Sales', 
         'Sales Director', 'Carol White', '2017-11-03', 'Berlin'),
        (7, 'Grace', 'Tanaka', 'grace.tanaka@company.com', 'Engineering', 
         'Frontend Developer', 'Bob Chen', '2022-01-15', 'Tokyo'),
        (8, 'Henry', 'O\'Connor', 'henry.oconnor@company.com', 'Marketing', 
         'Marketing Manager', 'Frank Müller', '2020-09-01', 'Dublin'),
        (9, 'Ibrahim', 'Hassan', 'ibrahim.hassan@company.com', 'Engineering', 
         'Security Engineer', 'Bob Chen', '2021-03-08', 'Dubai'),
        (10, 'Julia', 'Silva', 'julia.silva@company.com', 'HR', 
         'Recruiter', 'Elena Rodriguez', '2022-08-22', 'São Paulo')
    ]
    
    cursor.executemany('''
        INSERT OR REPLACE INTO employees 
        (id, first_name, last_name, email, department, role, manager, hire_date, location)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', employees)
    
    conn.commit()
    conn.close()
    
    print(f"Database initialized at {DB_PATH}")


@app.before_request
def get_user_from_headers():
    """
    Extrait les informations utilisateur des headers Cloudflare Access
    Ces headers sont injectés par Cloudflare Access après authentification
    """
    g.user_email = request.headers.get('CF-Access-Authenticated-User-Email')
    g.user_id = request.headers.get('CF-Access-Authenticated-User-Id')
    g.jwt_assertion = request.headers.get('CF-Access-Jwt-Assertion')
    
    # Pour debug : afficher tous les headers dans les logs
    # app.logger.debug(f"Request headers: {dict(request.headers)}")


@app.context_processor
def inject_user():
    """Injecte les informations utilisateur dans tous les templates"""
    return {
        'user_email': g.get('user_email'),
        'user_id': g.get('user_id'),
        'app_version': APP_VERSION
    }


@app.route('/')
def index():
    """Page d'accueil - Liste des employés"""
    try:
        conn = get_db_connection()
        employees = conn.execute(
            'SELECT * FROM employees ORDER BY last_name'
        ).fetchall()
        conn.close()
        
        return render_template('employees.html', employees=employees)
    except Exception as e:
        app.logger.error(f"Error loading employees: {e}")
        return render_template('error.html', error=str(e)), 500


@app.route('/employee/<int:employee_id>')
def employee_detail(employee_id):
    """Page de détail d'un employé"""
    try:
        conn = get_db_connection()
        employee = conn.execute(
            'SELECT * FROM employees WHERE id = ?', 
            (employee_id,)
        ).fetchone()
        conn.close()
        
        if employee is None:
            return render_template('error.html', error="Employee not found"), 404
        
        return render_template('employee_detail.html', employee=employee)
    except Exception as e:
        app.logger.error(f"Error loading employee {employee_id}: {e}")
        return render_template('error.html', error=str(e)), 500


@app.route('/profile')
def profile():
    """
    Page de profil utilisateur
    Affiche les informations extraites des headers Cloudflare Access JWT
    """
    # Récupérer tous les headers CF-Access-* pour debug
    cf_headers = {
        key: value for key, value in request.headers.items()
        if key.startswith('CF-Access') or key.startswith('Cf-Access')
    }
    
    return render_template(
        'profile.html',
        cf_headers=cf_headers,
        all_headers=dict(request.headers)
    )


@app.route('/api/employees')
def api_employees():
    """API JSON - Liste tous les employés (pour démo)"""
    try:
        conn = get_db_connection()
        employees = conn.execute('SELECT * FROM employees').fetchall()
        conn.close()
        
        return jsonify([dict(row) for row in employees])
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/employee/<int:employee_id>')
def api_employee(employee_id):
    """API JSON - Détail d'un employé"""
    try:
        conn = get_db_connection()
        employee = conn.execute(
            'SELECT * FROM employees WHERE id = ?', 
            (employee_id,)
        ).fetchone()
        conn.close()
        
        if employee is None:
            return jsonify({'error': 'Employee not found'}), 404
        
        return jsonify(dict(employee))
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/health')
def health():
    """Endpoint de health check"""
    return jsonify({
        'status': 'healthy',
        'version': APP_VERSION,
        'timestamp': datetime.utcnow().isoformat()
    })


@app.errorhandler(404)
def not_found(error):
    """Gestionnaire d'erreur 404"""
    return render_template('error.html', error="Page not found"), 404


@app.errorhandler(500)
def internal_error(error):
    """Gestionnaire d'erreur 500"""
    return render_template('error.html', error="Internal server error"), 500


if __name__ == '__main__':
    # Mode développement uniquement
    init_db()
    app.run(host='0.0.0.0', port=5000, debug=True)
