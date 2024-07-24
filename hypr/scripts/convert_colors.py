import re
import random

# Hardcoded file paths
input_file = "/home/jagan/.cache/wal/colors.sh"
output_file = "/home/jagan/.cache/wal/colors-hyprland.conf"

def hex_to_rgba(hex, alpha=1.0):
    r, g, b = tuple(int(hex[i:i+2], 16) for i in (0, 2, 4))
    return f"rgba({r}, {g}, {b}, {alpha})"

def main(alpha=1.0):
    try:
        with open(input_file, 'r') as file:
            content = file.read()

        # Adjusted regex to match color format in your file
        colors = re.findall(r'(color[0-9]+)=\'#([a-fA-F0-9]{6})\'', content)
        print(f"Found {len(colors)} colors.")  # Debug: Number of colors found

        if colors:
            with open(output_file, 'w') as output:
                # First 16 colors with default alpha 1.0
                for i, (color_name, hex_value) in enumerate(colors[:16]):
                    rgba_value = hex_to_rgba(hex_value, alpha)
                    output.write(f"${color_name}={rgba_value}\n")
                    print(f"${color_name}={rgba_value}")  # Debug: Print each line

                # Add the transparent color line
                output.write("$color16=rgba(0, 0, 0, 0)\n")
                print("$color16=rgba(0, 0, 0, 0)")  # Debug: Print the transparent color line

                # Next 16 colors with random alpha values
                for i, (color_name, hex_value) in enumerate(colors[:16]):
                    color_number = 17 + i
                    random_alpha = round(random.uniform(0.1, 0.9), 2)
                    rgba_value = hex_to_rgba(hex_value, random_alpha)
                    output.write(f"$color{color_number}={rgba_value}\n")
                    print(f"$color{color_number}={rgba_value}")  # Debug: Print each line

                # Add a solid white color
                output.write("$color33=rgba(255, 255, 255, 1.0)\n")
                print("$color33=rgba(255, 255, 255, 1.0)")  # Debug: Print the white color line

                # Print colors for visualization
                print("\nVisualize Colors:")
                for i, (color_name, hex_value) in enumerate(colors[:16]):
                    rgba_value = hex_to_rgba(hex_value, alpha)
                    print(f"{color_name}: {hex_value} -> {rgba_value}")
                
        else:
            print("No color patterns matched.")

    except Exception as e:
        print(f"Error: {e}")  # Debug: Print any errors

if __name__ == "__main__":
    main()

