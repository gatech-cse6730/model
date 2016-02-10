
# coding: utf-8

# In[1]:

"""
Code to write:
    Pedestrian class
    Node class
    Intersection class
    Driver/Simulation Executor class
    Visualization class
"""
        
class Node:
    """ Implementation of the Node structure in our graph. """
    
    """ 
    Creates a new Node. 
    
    Args:
      node_type: String. One of 'enter', 'exit', 'sidewalk', 'crosswalk'.
      x: Integer. The x-coordinate of the node in the grid.
      y: Integer. The y-coordinate of the node in the grid.
      
    Returns:
      A new Node object.
    
    """
    def __init__(self, node_id, node_type, x, y):
        # A unique identifier for the node.
        self.node_id = node_id
        
        # The node type.
        self.node_type = node_type
        
        # X and y coordinates for the node in the grid.
        self.x = x
        self.y = y
        
        # Initialize a dictionary to hold the next node in the shortest path
        # for each destination.
        self.paths = {}
        
        # Array of Node neighbors.
        self.neighbors = {}
        
        # By default, the node is not available (i.e., occupied).
        self.available = False
        
    def set_available(self, bool_val):
        self.available = bool_val
        
    def get_next_node(self, dest):
        pass
    
    def set_neighbors(self, neighbors):
        pass
    
    def get_neighbors(self):
        return self.neighbors
    
class Edge:
    def __init__(self, node_a, node_b, weight):
        self.node_a = node_a
        self.node_b = node_b
        self.weight = weight


# In[2]:

class Intersection:
    """ Implements an intersection """
    # Allen to implement
    def __init__(self):
        pass
    
    def close_me():
        pass
    
    def open_me():
        pass


# In[3]:

class Pedestrian:
    """ Implements a pedestrian. """
    
    """ 
    Creates a new Pedestrian. 
    
    Args:
      current: Node. A Node object corresponding to the current location of the
        pedestrian.
      destination: Node. A Node object corresponding to the destination node.
      speed: Integer. Number of grid cells traversed per time step. 
      
    Returns:
      A new Pedestrian object.
    
    """
    def __init__(self, current, destination, speed):
        # The current location of the pedestrian, as a Node.
        self.current = current
        
        # The pedestrian's final destination, as a Node.
        self.destination = destination
        
        # The speed of the pedestrian, formulated as an integer number of 
        # grid cells traversed per time step.
        self.speed = speed
        
        # The desired next node to move to.
        self.target_next = None
        
        # Whether the pedestrian has completed egress (i.e., exited the SUI).
        self.egress_complete = False
    
    """ 
    Moves the pedestrian to a new node.
    
    Args:
      node: Node. A Node object corresponding to the new location of the 
        pedestrian.
    
    Returns:
      Self. The current pedestrian object.
    
    """
    def move(self, node):
        self.current = node
        
        return self


# In[4]:

import csv

class Reader(object):
    def __init__(self, filename):
        self.filename = filename
        
        return self.process()
    
    def process(self):
        # Override in subclass.
        pass
    
class NodeReader(Reader):
    def __init__(self, filename):
        # Initialize a node container and a node dictionary.
        self.nodes = []
        self.node_dict = {}
        
        # Call __init__ on the parent class.
        super(NodeReader, self).__init__(filename)
    
    def process(self):
        with open(self.filename, 'rb') as csvfile:
            # Skip the first line.
            next(csvfile)

            # Create a CSV reader.
            reader = csv.reader(csvfile, delimiter=',')
            
            for indx, row in enumerate(reader):
                # The node_id for the Node will be indx + 1.
                node_id = indx #+ 1
                
                # Node type.
                node_type = int(row[6])
                
                # X and y coordinates.
                x = int(row[0])
                y = int(row[1])
                
                # Create a new node.
                newnode = Node(node_id, node_type, x, y)
                
                # Append it to the nodes array.
                self.nodes.append(newnode)
                
                # Add an entry in the node dictionary.
                self.node_dict[node_id] = newnode
                
        return self
        
class EdgeReader(Reader):
    def __init__(self, filename): 
        # Initialize an edges container.
        self.edges = []
        
        # Call __init__ on the parent class.
        super(EdgeReader, self).__init__(filename)
        
    def process(self):
        with open(self.filename, 'rb') as csvfile:
            # Skip the first line.
            next(csvfile)

            # Create a CSV reader.
            reader = csv.reader(csvfile, delimiter=',')
            
            for row in reader:
                # The node_a and node_b corresponding to node_ids.
                node_a = int(row[0])
                node_b = int(row[1])
                
                # The weight is a float value that will be used for computations.
                weight = float(row[2])
                
                # Create a new edge.
                newedge = Edge(node_a, node_b, weight)
                
                # Append it to the edges array.
                self.edges.append(newedge)
        
        return self
        
class Grid:    
    def __init__(self, max_rows, max_cols, node_file, edge_file):
        self.max_rows = max_rows
        self.max_cols = max_cols
        self.node_file = node_file
        self.edge_file = edge_file
        
        self.initialize_grid()
        self.initialize_nodes()
        self.initialize_edges()
        
    def initialize_grid(self):
        self.grid = [[0 for x in range(self.max_cols)] for x in range(self.max_rows)]
        
    def initialize_nodes(self):
        reader = NodeReader(self.node_file)
        
        # Save the node dict for later lookups.
        self.node_dict = reader.node_dict
        
        # Save off the node array.
        nodes = reader.nodes
        
        # Iterate through the returned nodes, adding each node to the grid in the
        # appropriate location.
        for node in nodes:
            self.grid[node.y-1][node.x-1] = node
            
    def initialize_edges(self):
        reader = EdgeReader(self.edge_file)
        
        # Save off the edges array.
        edges = reader.edges
        
        for edge in edges:
            # Look up the first node.
            node_a = self.node_dict[edge.node_a]
            
            # Look up the second node to make sure it exists.
            node_b = self.node_dict[edge.node_b]
            
            # Add a new entry to node a's neighbors dict for node b, setting it
            # to the weight.
            node_a.neighbors[node_b.node_id] = edge.weight


# In[5]:

max_rows = 66
max_cols = 139

grid = Grid(max_rows, max_cols, 'playMat.png.vertex.stripped', 'playMat.png.edge.stripped')

