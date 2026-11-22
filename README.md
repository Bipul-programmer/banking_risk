# Banking & Financial Risk Analytics

An end-to-end financial risk analysis and default prediction project using applicant credit history, bureau records, and repayment data.

## Project Structure

```
Banking-Financial-Risk-Analytics/
├── .vscode/               # Workspace settings (Python interpreter & Jupyter configuration)
├── datasets/
│   ├── raw/               # Raw Home Credit Default Risk datasets
│   └── processed/         # Cleaned and engineered features
├── python/
│   └── data_exploration.ipynb  # Exploratory Data Analysis (EDA) notebook
├── sql/                   # SQL queries and aggregations
├── aws/                   # AWS deployment and cloud storage scripts
├── powerbi/               # Power BI dashboards and visual reports
├── documentation/         # Data dictionaries and project documentation
├── reports/               # Risk summary and presentation reports
├── requirements.txt       # Project dependencies
└── venv/                  # Python 3.12 virtual environment
```

---

## Jupyter Notebook Environment Setup

### Option 1: Running in Antigravity / VS Code (Recommended)
1. Open [`python/data_exploration.ipynb`](file:///Users/bipulkumar/Desktop/Banking-Financial-Risk-Analytics/python/data_exploration.ipynb).
2. Look at the top right of the notebook editor for the kernel picker.
3. Click **Select Kernel** -> **Python Environments...** -> Select **Python (Banking Risk Analytics)** or `./venv/bin/python`.
4. Run cells sequentially using `Shift + Enter`.

### Option 2: Running JupyterLab or Jupyter Notebook in the Browser
Activate the virtual environment and start Jupyter:

```bash
# 1. Activate the environment
source venv/bin/activate

# 2. Launch Jupyter Lab or Notebook
jupyter lab
# or
jupyter notebook
```

The browser will open automatically at `http://localhost:8888`.
# banking_risk
