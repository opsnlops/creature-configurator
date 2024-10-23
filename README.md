# Creature Configurator

This application generates the config that gets burned into the EEPROM of something from April's Creature Workshop.

## Configuration File Format

This table outlines the binary file format used to store USB configuration data, including custom user-defined strings.

| **Offset** | **Size** | **Field**             | **Description**                                                                 |
|------------|----------|-----------------------|---------------------------------------------------------------------------------|
| 0x00       | 4 bytes  | Magic Number           | The ASCII string "HOP!" to identify the file type.                              |
| 0x04       | 2 bytes  | USB VID                | USB Vendor ID, stored as a big-endian 16-bit integer.                           |
| 0x06       | 2 bytes  | USB PID                | USB Product ID, stored as a big-endian 16-bit integer.                          |
| 0x08       | 2 bytes  | Version                | Version in BCD format, stored as two 8-bit values (major and minor).            |
| 0x0A       | 1 byte   | Logging Level          | Logging level, as defined by the application (0 = Fatal, 5 = Verbose).          |
| 0x0B       | 1 byte   | Serial Number Length   | Length of the serial number string in bytes.                                    |
| 0x0C       | N bytes  | Serial Number          | Serial number string in UTF-8 format.                                           |
| 0x0C + N   | 1 byte   | Product Name Length    | Length of the product name string in bytes.                                     |
| N + 1      | M bytes  | Product Name           | Product name string in UTF-8 format.                                            |
| N + M + 1  | 1 byte   | Manufacturer Length    | Length of the manufacturer string in bytes.                                     |
| N + M + 2  | L bytes  | Manufacturer           | Manufacturer string in UTF-8 format.                                            |
| ...        | 1 byte   | Custom String Length   | Length of a custom user-defined string in bytes (repeated for each custom string).|
| ...        | X bytes  | Custom String          | Custom user-defined string in UTF-8 format (repeated for each custom string).    |

- **USB VID/USB PID**: 16-bit values representing the Vendor ID and Product ID of the USB device.
- **Version**: Two bytes stored in BCD format (Binary-Coded Decimal) to represent major and minor versions.
- **Strings**: All strings are stored as length-prefixed UTF-8 encoded data.
- **Custom Strings**: Any number of user-defined strings can be added, each prefixed with its length.
