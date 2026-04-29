#!/usr/bin/env python3
"""
WSGI entry point for HR Directory application
"""
import os
import sys

# Add the app directory to the path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import app, init_db

# Initialize database on first run
if __name__ == "__main__":
    try:
        init_db()
        print("Database initialized successfully")
    except Exception as e:
        print(f"Database initialization warning (may already exist): {e}")
    
    # Run the app
    app.run()
