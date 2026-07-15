# R Snippets Reference

Quick reference for all custom R snippets in VS Code.

| Snippet Name | Prefix | Description |
|--------------|--------|-------------|
| Function Definition | `fun` | Create a standard R function |
| For Loop | `for` | Standard for loop |
| Timestamp | `ts` | Inserts a timestamp with your mdp handle |
| Shiny App | `shinyapp` | Basic Shiny application skeleton |
| Header Title | `hh` | Script header with title and author |
| ggplot Scatter and Line | `ggp` | Standard ggplot with scatter and line, and automatic ggsave |
| Remove Objects and Columns | `rm` | Remove specified objects and data frame columns |
| Data Frame Column List | `dflist` | Paste data frame column names collapsed by comma |
| Write Timestamped CSV | `time` | Write a data frame to a timestamped CSV |
| Pivot Longer | `plonger` | Tidyr pivot_longer |
| Pivot Wider | `pwider` | Tidyr pivot_wider |
| Setup Script | `setup` | Source a setup file |
| Nix Path | `npath` | Reformat path from clipboard |
| Project Setup | `Proj` | Create project folders |

## Usage

Type the **prefix** in any R file and press `Tab` to expand the snippet.

### Examples

- Type `fun` + Tab → Creates a function template
- Type `Proj` + Tab → Creates csv_output, plots, and source_data folders
- Type `ggp` + Tab → Creates a ggplot with scatter/line and saves to PDF
- Type `ts` + Tab → Inserts a timestamp comment

---

*Snippet file location: `C:\Users\mike.proctor\AppData\Roaming\Code\User\snippets\r.json`*
