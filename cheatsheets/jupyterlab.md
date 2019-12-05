# Jupyter-lab installation:

```bash
conda install -c conda-forge jupyterlab
jupyter labextension install @jupyterlab/toc  # Table Of Content

# Plotly
jupyter labextension install @jupyterlab/plotly-extension  # Get plotly embed

# Bokeh
jupyter labextension install @jupyter-widgets/jupyterlab-manager
jupyter labextension install @bokeh/jupyter_bokeh

pip install jupyter_contrib_nbextensions  # Necessary to export to embed figures html
jupyter-nbconvert --to html_embed notebooks/plotlyink_tutorial.ipynb  # to convert into embed html
```
