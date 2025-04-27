import os
import sys
import subprocess
import pkg_resources

FAISS_PACKAGE = "faiss-cpu"

def is_package_installed(package_name):
    """Check if a package is installed."""
    try:
        pkg_resources.get_distribution(package_name)
        print(f"'{package_name}' is already installed.")
        return True
    except pkg_resources.DistributionNotFound:
        print(f"'{package_name}' not found.")
        return False
    except Exception as e:
        print(f"Error checking for package '{package_name}': {e}")
        # Assume not installed if there's an error checking
        return False

def install_package(package_name):
    """Install a package using pip3."""
    print(f"Attempting to install '{package_name}'...")
    try:
        # Ensure using the same Python interpreter that's running this script
        # Use pip3 specifically as requested
        # Construct the path to pip3 based on sys.executable
        python_executable = sys.executable
        pip3_executable = os.path.join(os.path.dirname(python_executable), 'pip3')
        
        # Fallback if replacing 'python' doesn't yield 'pip3' (e.g., venv)
        if not os.path.exists(pip3_executable):
             pip3_executable = 'pip3' # Assume pip3 is in PATH if direct construction fails

        print(f"Using pip executable: {pip3_executable}")
        subprocess.check_call([pip3_executable, "install", package_name])
        print(f"Successfully installed '{package_name}'.")
        # Clear pkg_resources cache after installation to recognize the new package
        pkg_resources.working_set = pkg_resources.WorkingSet._build_master() 
        return True
    except subprocess.CalledProcessError as e:
        print(f"Failed to install '{package_name}'. Error: {e}")
        return False
    except FileNotFoundError:
        print(f"Error: '{pip3_executable}' command not found. Make sure pip is installed and accessible.")
        return False


def run_application():
    """Run the FastAPI application using uvicorn."""
    port = os.getenv("PORT", "8005") # Default to 8000 if PORT env var not set
    host = "0.0.0.0"
    app_module = "app:app"
    
    print(f"Starting application '{app_module}' on {host}:{port}...")
    
    # Check if reload should be enabled (e.g., based on an environment variable)
    # For simplicity, enabling reload by default for local dev feel.
    # In production, you might want this disabled or controlled via env var.
    reload_flag = "--reload" 
    
    try:
        subprocess.check_call([
            sys.executable, "-m", "uvicorn", 
            app_module, 
            "--host", host, 
            "--port", port,
            reload_flag
        ])
    except subprocess.CalledProcessError as e:
        print(f"Failed to run application. Error: {e}")
    except FileNotFoundError:
        print("Error: Python executable or uvicorn module not found.")
        print("Ensure uvicorn is installed (it should be in requirements.txt).")

if __name__ == "__main__":
    # Check if FAISS is installed
    if not is_package_installed(FAISS_PACKAGE):
        # If not, try to install it
        if not install_package(FAISS_PACKAGE):
            print(f"Could not install '{FAISS_PACKAGE}'. Exiting.")
            sys.exit(1) # Exit if installation fails
        else:
            # Verify installation succeeded
             if not is_package_installed(FAISS_PACKAGE):
                print(f"Installation command ran, but '{FAISS_PACKAGE}' still not detected. Exiting.")
                sys.exit(1)

    # Run the main application
    run_application() 