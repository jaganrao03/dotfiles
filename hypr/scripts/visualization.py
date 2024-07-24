import matplotlib.pyplot as plt
import re

# Hardcoded file paths
input_file = "/home/jagan/.cache/wal/colors-hyprland.conf"

def parse_colors(file_path):
    with open(file_path, 'r') as file:
        content = file.read()

    colors = re.findall(r'\$(color[0-9]+)=rgba\((\d+), (\d+), (\d+), ([0-9.]+)\)', content)
    return colors

def plot_colors(colors):
    fig, ax = plt.subplots(figsize=(14, len(colors) * 0.8))
    fig.patch.set_facecolor('black')
    ax.set_facecolor('black')

    for i, (color_name, r, g, b, a) in enumerate(colors):
        rgba = (int(r) / 255, int(g) / 255, int(b) / 255, float(a))
        ax.add_patch(plt.Rectangle((0, i * 2.2), 1, 1, color=rgba, ec='white', lw=1))
        ax.text(1.2, i * 2.2 + 0.5, f"{color_name}: rgba({r}, {g}, {b}, {a})", va='center', color='white', fontsize=10, fontfamily='monospace')

        # Highlight specific colors
        if color_name == 'color16':
            ax.text(2.4, i * 2.2 + 0.5, "(Transparent)", va='center', color='cyan', fontsize=10, fontfamily='monospace')
        elif color_name == 'color33':
            ax.text(2.4, i * 2.2 + 0.5, "(White)", va='center', color='cyan', fontsize=10, fontfamily='monospace')

    ax.set_xlim(0, 3.5)
    ax.set_ylim(0, len(colors) * 2.2)
    ax.set_aspect('auto')
    ax.axis('off')

    plt.tight_layout()
    plt.show()

if __name__ == "__main__":
    colors = parse_colors(input_file)
    plot_colors(colors)

