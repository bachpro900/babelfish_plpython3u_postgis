
USE [master]
GO
CREATE DATABASE [Retail]
GO
USE [Retail];
GO

CREATE SCHEMA Sales;
GO
CREATE SCHEMA Inventory;
GO

CREATE TABLE Sales.Orders (
    OrderID INT PRIMARY KEY,
    ProductID INT,
    Quantity INT,
    OrderDate DATE
);
INSERT INTO Sales.Orders VALUES (1, 101, 10, '2023-09-01');
INSERT INTO Sales.Orders VALUES (2, 102, 5, '2023-09-02');
INSERT INTO Sales.Orders VALUES (3, 101, 8, '2023-09-03');

CREATE TABLE Inventory.Products (
    ProductID INT PRIMARY KEY,
    ProductName NVARCHAR(100),
    StockLevel INT
);
INSERT INTO Inventory.Products VALUES (101, 'Bicycle', 50);
INSERT INTO Inventory.Products VALUES (102, 'Helmet', 100);
GO

CREATE PROCEDURE Sales.GetOrderVehicleInfo
AS
BEGIN
    SELECT 
        o.OrderID,
        o.ProductID,
        p.ProductName,
        t.VehicleID,
        v.VehicleType
    FROM Sales.Orders o
    JOIN Transport.Operations.Transactions t ON o.OrderID = t.TransactionID
    JOIN Transport.Fleet.Vehicles v ON t.VehicleID = v.VehicleID
    JOIN Inventory.Products p ON o.ProductID = p.ProductID;
END;
GO

CREATE FUNCTION Inventory.GetProductAvailability (@ProductID INT)
RETURNS NVARCHAR(50)
AS
BEGIN
    DECLARE @StockLevel INT;
    DECLARE @Availability NVARCHAR(50);
    
    SELECT @StockLevel = StockLevel
    FROM Inventory.Products
    WHERE ProductID = @ProductID;
    
    IF @StockLevel IS NULL
    BEGIN
        SET @Availability = 'Produit inconnu';
    END
    ELSE IF @StockLevel = 0
    BEGIN
        SET @Availability = 'En rupture de stock';
    END
    ELSE IF @StockLevel <= 5
    BEGIN
        SET @Availability = 'Stock faible';
    END
    ELSE
    BEGIN
        SET @Availability = 'En stock';
    END
    
    RETURN @Availability;
END;
GO

USE [master]
GO
CREATE DATABASE [Transport];
GO
USE [Transport]
GO

CREATE SCHEMA Operations;
GO
CREATE SCHEMA Fleet;
GO

CREATE TABLE Operations.Transactions (
    TransactionID INT PRIMARY KEY,
    VehicleID INT,
    TransactionDate DATE,
    MilesDriven INT
);
INSERT INTO Operations.Transactions VALUES (1, 201, '2023-09-01', 100);
INSERT INTO Operations.Transactions VALUES (2, 202, '2023-09-02', 200);

CREATE TABLE Fleet.Vehicles (
    VehicleID INT PRIMARY KEY,
    VehicleType NVARCHAR(50),
    AvailabilityStatus NVARCHAR(20)
);

INSERT INTO Fleet.Vehicles VALUES (201, 'Truck', 'Available');
INSERT INTO Fleet.Vehicles VALUES (202, 'Van', 'In Repair');
