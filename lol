#!/usr/bin/env python3



import os
import sys
import aiohttp
import asyncio
import uvloop



# Global constants
DEFAULT_CHUNK_SIZE = 8192



# Exception types
class FetchError(Exception): pass



# Download a file in chunks to a desired path.
async def download_file(session, url, path, chunk_size=DEFAULT_CHUNK_SIZE):
	print("saving: " + path)

	async with session.get(url) as resp:
		with open(path, "wb") as f:
			while True:
				chunk = await resp.content.read(chunk_size)

				if not chunk:
					break

				f.write(chunk)



# Downloads all the files in a folder recursively.
async def package_fetch(root, repo, pkg, branch="master", chunk_size=DEFAULT_CHUNK_SIZE):
	url = "https://api.github.com/repos/{}/contents/{}?ref={}".format(repo, pkg, branch)

	async with aiohttp.ClientSession() as session: # Setup a session
		j = None

		async with session.get(url) as r: # Fetch the directory listing on github.
			if r.status != 200:
				print(f"error: {r.status}")
				raise FetchError("failed to retrieve resource!")

			j = await r.json() # Decode the JSON


		for item in j:
			name = item["name"]
			path = item["path"]
			full_path = os.path.join(root, path)
			url  = item["download_url"]
			type = item["type"]


			if type == "file": # If it's a file, download it.
				folder_name = os.path.dirname(full_path)

				if not os.path.isdir(folder_name):
					os.mkdir(folder_name)

				await download_file(session, url, full_path, chunk_size)


			elif type == "dir": # If it's a directory, recurse.
				await package_fetch(repo, pkg, branch)



if __name__ == "__main__":
	argc = len(sys.argv) - 1
	argv = sys.argv[1:]


	if argc == 0:
		print("specify a mode.")
		sys.exit(1)


	if argv[0] == "fetch":
		argc -= 1
		argv = argv[1:]

		if argc != 3:
			print("fetch requires more args.")
			sys.exit(2)

		repo = argv[0]
		root = "test"
		branch = argv[1]
		pkg = argv[2]


		# Setup event loop and run our coroutine.
		asyncio.set_event_loop_policy(uvloop.EventLoopPolicy())

		loop = asyncio.get_event_loop()
		loop.run_until_complete(package_fetch(root, repo, pkg, branch))
		loop.close()




