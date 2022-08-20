import brotlicffi

f = open("test.html", "rb")
contents = f.read()
print(len(contents))
f.close()

result = brotlicffi.compress(contents)
print(len(contents), len(result))