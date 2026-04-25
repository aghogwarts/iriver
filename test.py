import usb.core
import usb.util

dev = usb.core.find(idVendor=0x4102, idProduct=0x1001)

if dev is None:
    print("Device not found")
else:
    print("Device found")
    dev.set_configuration()
