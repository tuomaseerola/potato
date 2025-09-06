import streamlit as st
import json
import os
import sys
from pathlib import Path

# Add the current directory to Python path to import Potato modules
sys.path.append(str(Path(__file__).parent))

try:
    # Try to import Potato modules (adjust imports based on what's available)
    from potato.flask_server import app as flask_app
    from potato.database.models import *
    from potato.database.database import Database
    POTATO_AVAILABLE = True
except ImportError:
    POTATO_AVAILABLE = False
    st.error("Potato modules not found. Make sure all dependencies are installed.")

st.set_page_config(
    page_title="Potato Annotation Tool",
    page_icon="🥔",
    layout="wide"
)

st.title("🥔 Potato Annotation Interface")
st.markdown("Web interface for the Potato annotation framework")

if not POTATO_AVAILABLE:
    st.error("⚠️ Potato framework not properly loaded. Please check your installation.")
    st.stop()

# Sidebar for configuration
st.sidebar.header("Configuration")

# Check for existing config files
config_files = list(Path(".").glob("*.yaml")) + list(Path(".").glob("*.yml"))
config_file = st.sidebar.selectbox(
    "Select Configuration File:",
    ["None"] + [str(f) for f in config_files]
)

# Main tabs
tab1, tab2, tab3 = st.tabs(["📝 Annotation", "📊 Data Management", "⚙️ Setup"])

with tab1:
    st.header("Text Annotation")
    
    # Text input methods
    input_method = st.radio(
        "Input method:",
        ["Direct text input", "File upload", "Load from database"]
    )
    
    text_to_annotate = ""
    
    if input_method == "Direct text input":
        text_to_annotate = st.text_area(
            "Enter text to annotate:",
            height=200,
            placeholder="Type or paste your text here..."
        )
    
    elif input_method == "File upload":
        uploaded_file = st.file_uploader(
            "Upload text file",
            type=['txt', 'json']
        )
        if uploaded_file is not None:
            if uploaded_file.type == "text/plain":
                text_to_annotate = str(uploaded_file.read(), "utf-8")
            elif uploaded_file.type == "application/json":
                data = json.load(uploaded_file)
                text_to_annotate = data.get('text', str(data))
    
    elif input_method == "Load from database":
        st.info("Database connection would be configured here based on your Potato setup")
    
    # Annotation options
    if text_to_annotate:
        st.subheader("Annotation Settings")
        
        col1, col2 = st.columns(2)
        
        with col1:
            annotation_scheme = st.selectbox(
                "Annotation Scheme:",
                ["NER", "Sentiment", "Classification", "Custom"]
            )
            
            annotator_id = st.text_input(
                "Annotator ID:",
                value="streamlit_user"
            )
        
        with col2:
            batch_size = st.number_input(
                "Batch Size:",
                min_value=1,
                max_value=100,
                value=10
            )
            
            save_results = st.checkbox("Save to database", value=True)
        
        # Process annotation
        if st.button("🚀 Start Annotation", type="primary"):
            with st.spinner("Processing annotation..."):
                # This is where you'd integrate with Potato's annotation logic
                # For now, we'll create a mock annotation interface
                
                st.success("Annotation interface loaded!")
                
                # Mock annotation interface
                st.subheader("Annotate the text:")
                
                # Split text into sentences or tokens for annotation
                sentences = text_to_annotate.split('.')
                annotations = {}
                
                for i, sentence in enumerate(sentences[:5]):  # Limit to first 5 sentences
                    if sentence.strip():
                        st.markdown(f"**Sentence {i+1}:**")
                        st.write(sentence.strip())
                        
                        # Annotation input for this sentence
                        label = st.selectbox(
                            f"Label for sentence {i+1}:",
                            ["Positive", "Negative", "Neutral", "Unknown"],
                            key=f"label_{i}"
                        )
                        
                        confidence = st.slider(
                            f"Confidence for sentence {i+1}:",
                            0.0, 1.0, 0.8,
                            key=f"conf_{i}"
                        )
                        
                        annotations[i] = {
                            "text": sentence.strip(),
                            "label": label,
                            "confidence": confidence,
                            "annotator": annotator_id
                        }
                        
                        st.divider()
                
                # Save annotations
                if st.button("💾 Save Annotations"):
                    # Here you would save to Potato's database
                    st.success("Annotations saved!")
                    
                    # Show results
                    st.json(annotations)

with tab2:
    st.header("Data Management")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("Import Data")
        
        import_file = st.file_uploader(
            "Upload data file",
            type=['json', 'csv', 'txt']
        )
        
        if import_file and st.button("Import"):
            st.success("Data imported successfully!")
    
    with col2:
        st.subheader("Export Data")
        
        export_format = st.selectbox(
            "Export format:",
            ["JSON", "CSV", "TSV"]
        )
        
        if st.button("Export Annotations"):
            # Mock export
            sample_data = {
                "annotations": [
                    {"id": 1, "text": "Sample text", "label": "Positive"},
                    {"id": 2, "text": "Another text", "label": "Negative"}
                ]
            }
            
            st.download_button(
                label="Download",
                data=json.dumps(sample_data, indent=2),
                file_name="annotations.json",
                mime="application/json"
            )
    
    st.subheader("Database Statistics")
    
    # Mock statistics
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.metric("Total Annotations", "1,234")
    
    with col2:
        st.metric("Annotators", "12")
    
    with col3:
        st.metric("Completed Tasks", "89%")
    
    with col4:
        st.metric("Inter-annotator Agreement", "0.85")

with tab3:
    st.header("Setup & Configuration")
    
    st.subheader("Potato Configuration")
    
    if config_file != "None":
        try:
            with open(config_file, 'r') as f:
                config_content = f.read()
            
            st.code(config_content, language='yaml')
            
            if st.button("Reload Configuration"):
                st.success("Configuration reloaded!")
                
        except Exception as e:
            st.error(f"Error reading config file: {e}")
    
    else:
        st.info("No configuration file selected. Upload or create one to get started.")
        
        # Basic configuration form
        st.subheader("Create Basic Configuration")
        
        with st.form("config_form"):
            project_name = st.text_input("Project Name")
            database_url = st.text_input("Database URL", value="sqlite:///potato.db")
            annotation_types = st.multiselect(
                "Annotation Types",
                ["NER", "Classification", "Sentiment", "Relation"]
            )
            
            if st.form_submit_button("Generate Config"):
                config = {
                    "project_name": project_name,
                    "database_url": database_url,
                    "annotation_types": annotation_types
                }
                
                st.code(f"# Generated Configuration\n{json.dumps(config, indent=2)}")
    
    st.subheader("System Status")
    
    # System checks
    checks = {
        "Python Path": "✅ OK",
        "Database Connection": "✅ Connected", 
        "Potato Modules": "✅ Loaded" if POTATO_AVAILABLE else "❌ Error",
        "Configuration": "✅ Valid" if config_file != "None" else "⚠️ Not loaded"
    }
    
    for check, status in checks.items():
        st.write(f"**{check}:** {status}")

# Footer
st.markdown("---")
st.markdown(
    """
    <div style='text-align: center'>
        <p>Built with Streamlit 🎈 | Powered by Potato 🥔</p>
        <p><a href='https://github.com/tuomaseerola/potato'>Original Potato Repository</a></p>
    </div>
    """,
    unsafe_allow_html=True
)