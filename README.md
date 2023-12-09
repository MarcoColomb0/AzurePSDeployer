# AzurePSDeployer

AzurePSDeployer is a PowerShell script designed to simplify and automate the deployment of resources in Microsoft Azure. This tool aims to streamline the process of provisioning Azure resources, making it more efficient and user-friendly.

[Skip to Usage (execution commands)](#usage)

## Features

- Fully customizable, you can create your own templates in /deployments and run them locally (or contribute to the project and [submit a pull request](#how-to-contribute))
- Checks if the Az module is present and fully functional
- Validates and sets the Azure account for deployment
- Confirms the selected subscription by prompting the user to choose one
- Automates the creation of:
  - Resource groups
  - Virtual networks and subnets
  - Public IP addresses
  - Network security groups and their rules
  - Network interface cards
  - Virtual machines
- Provides a general summary of the created resources
- Automates the RDP connection

## Prerequisites

Before using AzurePSDeployer, ensure that you have the following prerequisites in place:

- Windows machine (could work on other OSes too)
- PowerShell 5.0+
- Azure account and a working subscription

## Usage

To use AzurePSDeployer, follow the steps below:

> [!WARNING]
> You may need to modify the ExecutionPolicy on your machine (administration privileges are needed):
```
Set-ExecutionPolicy Bypass
```

### Method #1 (fastest)
Using the shortened link and executing the script using `Invoke-WebRequest`
```
iwr l.marco.wf/deploy | iex
```
### Method #2
Using the raw version of the script using `Invoke-WebRequest`
```
iwr https://github.com/MarcoColomb0/AzurePSDeployer/raw/main/AzurePSDeployer.ps1 | iex
```
### Method #3 (you are able to fully trust the code 😊)
Cloning the repository or downloading it as an [archive](https://github.com/MarcoColomb0/AzurePSDeployer/archive/refs/heads/main.zip) on your local machine


> [!IMPORTANT]  
> The log file is saved in the current user's temp folder (%temp%). The filename is composed of $VMName (the virtual machine name defined in the variables) and the execution date

## Credits

This project is maintained by [MarcoColomb0](https://github.com/MarcoColomb0).

You can find me at:
- [My website](https://marco.wf)
- [LinkedIn](https://linkedin.com/in/marcocolomb0)
- [Twitter](https://twitter.com/MarcoColomb0)

## How to Contribute

If you'd like to contribute to AzurePSDeployer, follow these steps:

1. Fork the repository.
2. Create a new branch for your feature or bug fix:
```
git checkout -b feature/new-feature
```
3. Make your changes and commit them:
```
git commit -m 'Description of changes'
```
4. Push your changes to your fork:
```
git push origin feature/new-feature
```
5. Open a pull request on the main repository, describing your changes and referencing any related issues.

### Contributor Guidelines

- Maintain a clean and consistent coding style.
- Write clear and comprehensive documentation for new features or changes.
- Test your changes thoroughly before submitting a pull request.

Thank you for contributing to AzurePSDeployer! Your efforts are greatly appreciated.
